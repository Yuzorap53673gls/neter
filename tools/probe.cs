// probe.cs — independent read-only verifier for the Roblox external ESP offsets.
// Build:  %WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe /platform:x64 /out:probe.exe probe.cs
// Run:    probe.exe            (dump globals + standard chain + players)
//         probe.exe --discover (scan the exe image for a verified FakeDataModel global)
//
// The probe deliberately shares no code or cache with rbx_esp.exe. It uses only
// PROCESS_VM_READ | PROCESS_QUERY_LIMITED_INFORMATION and never writes memory.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class Probe
{
    // ---- offset profile (must match src/offsets.h) ----
    private const string ProfileVersion = "version-11f155f3450f4c8e";
    private const ulong VisualEnginePointer = 0x884C2E0;
    private const ulong FakeDataModelPointer = 0x8DC8000;

    private const int VisualEngineDimensions = 0xB10;
    private const int VisualEngineViewMatrix = 0x1B0;
    private const int VisualEngineRenderView = 0xC38;
    private const int VisualEngineFakeDataModel = 0xAF0;
    private const int FakeDataModelRealDataModel = 0x1F8;

    private const int InstanceNameContainer = 0x70;
    private const int InstanceName = 0x8;
    private const int InstanceChildrenStart = 0x78;
    private const int InstanceChildrenEnd = 0x8;
    private const int InstanceChildStride = 0x10;
    private const int StringLength = 0x10;

    private const int DataModelGameLoaded = 0x5D0;
    private const int DataModelWorkspace = 0x150;
    private const int DataModelPlaceId = 0x188;
    private const int DataModelJobId = 0x110;

    private const int WorkspaceCurrentCamera = 0x4A8;

    private const int PlayerLocalPlayer = 0x120;
    private const int PlayerUserId = 0xC0;
    private const int PlayerModelInstance = 0x298;
    private const int PlayerTeam = 0x2D8;
    private const int PlayerTeamColor = 0x3B0;

    private const int HumanoidHealth = 0x18C;
    private const int HumanoidMaxHealth = 0x1A4;
    private const int HumanoidRootPart = 0x468;
    private const int HumanoidDisplayName = 0xA8;

    private const int BasePartPrimitive = 0x180;
    private const int PrimitivePosition = 0xD4;
    private const int PrimitiveSize = 0x1C4;
    private const int ModelPrimaryPart = 0x248;

    private const int CameraPosition = 0xEC;
    private const int CameraRotation = 0xC8;
    private const int CameraFov = 0x130;
    private const int CameraViewportSize = 0x2CC;

    private const ulong MinPtr = 0x10000;
    private const ulong MaxPtr = 0x7FFFFFFEFFFF;

    // ---- win32 ----
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr h);

    [DllImport("kernel32.dll")]
    private static extern bool IsWow64Process(IntPtr h, out bool wow64);

    [DllImport("psapi.dll")]
    private static extern bool EnumProcessModulesEx(IntPtr h, [Out] IntPtr[] mods, int cb, out int needed, uint filter);

    [DllImport("psapi.dll", CharSet = CharSet.Unicode)]
    private static extern int GetModuleBaseNameW(IntPtr h, IntPtr mod, StringBuilder name, int n);

    [DllImport("psapi.dll", CharSet = CharSet.Unicode)]
    private static extern bool GetModuleInformation(IntPtr h, IntPtr mod, out ModuleInfo mi, int cb);

    [StructLayout(LayoutKind.Sequential)]
    private struct ModuleInfo
    {
        public IntPtr Base;
        public uint Size;
        public IntPtr Entry;
    }

    private sealed class Mem
    {
        public IntPtr Handle;
        public ulong Base;
        public ulong Size;

        public bool Read(ulong addr, byte[] buf)
        {
            if (Handle == IntPtr.Zero || addr < MinPtr || addr > MaxPtr || buf.Length == 0)
                return false;
            IntPtr got;
            if (!ReadProcessMemory(Handle, (IntPtr)(long)addr, buf, (IntPtr)buf.Length, out got))
                return false;
            return got.ToInt64() == buf.Length;
        }

        public ulong U64(ulong addr)
        {
            var b = new byte[8];
            return Read(addr, b) ? BitConverter.ToUInt64(b, 0) : 0;
        }

        public int I32(ulong addr)
        {
            var b = new byte[4];
            return Read(addr, b) ? BitConverter.ToInt32(b, 0) : 0;
        }

        public float F32(ulong addr)
        {
            var b = new byte[4];
            return Read(addr, b) ? BitConverter.ToSingle(b, 0) : float.NaN;
        }

        public float[] Floats(ulong addr, int count)
        {
            var b = new byte[count * 4];
            if (!Read(addr, b))
                return null;
            var v = new float[count];
            for (int i = 0; i < count; i++)
                v[i] = BitConverter.ToSingle(b, i * 4);
            return v;
        }

        public bool Plausible(ulong p)
        {
            return p >= MinPtr && p <= MaxPtr && (p & 3) == 0;
        }

        // Roblox instance name: NameContainer -> inline/SSO length + data.
        public string Name(ulong instance)
        {
            ulong container = U64(instance + (ulong)InstanceNameContainer);
            if (container == 0)
                return null;
            int len = I32(container + (ulong)StringLength);
            if (len <= 0 || len > 256)
                return null;
            ulong data = len <= 15 ? container + (ulong)InstanceName : U64(container + (ulong)InstanceName);
            if (!Plausible(data))
                return null;
            var bytes = new byte[len];
            if (!Read(data, bytes))
                return null;
            for (int i = 0; i < len; i++)
                if (bytes[i] == 0)
                    return null;
            return Encoding.UTF8.GetString(bytes);
        }

        // Vector descriptor: inst+0x78 -> descriptor; descriptor+0x0 = begin, +0x8 = end; stride 0x10.
        public List<ulong> Children(ulong instance)
        {
            var list = new List<ulong>();
            ulong desc = U64(instance + (ulong)InstanceChildrenStart);
            if (desc == 0)
                return list;
            ulong begin = U64(desc);
            ulong end = U64(desc + (ulong)InstanceChildrenEnd);
            if (begin < MinPtr || end < begin || end > MaxPtr)
                return list;
            ulong bytes = end - begin;
            if (bytes == 0 || bytes > 512 * (ulong)InstanceChildStride || bytes % (ulong)InstanceChildStride != 0)
                return list;
            var raw = new byte[bytes];
            if (!Read(begin, raw))
                return list;
            for (ulong off = 0; off + 8 <= bytes; off += (ulong)InstanceChildStride)
            {
                ulong child = BitConverter.ToUInt64(raw, (int)off);
                if (Plausible(child))
                    list.Add(child);
            }
            return list;
        }

        public ulong ChildNamed(ulong parent, string name, out ulong found)
        {
            found = 0;
            List<ulong> kids = Children(parent);
            foreach (ulong kid in kids)
            {
                if (Name(kid) == name)
                {
                    found = kid;
                    return kid;
                }
            }
            return 0;
        }

        public ulong FindChild(ulong parent, string name)
        {
            List<ulong> kids = Children(parent);
            foreach (ulong kid in kids)
                if (Name(kid) == name)
                    return kid;
            return 0;
        }
    }

    private static Mem _mem;
    private static string _exePath;

    private static string VersionFolder()
    {
        string running = null;
        try
        {
            foreach (Process p in Process.GetProcessesByName("RobloxPlayerBeta"))
            {
                try { running = p.MainModule.FileName; break; }
                catch { }
            }
        }
        catch { }
        if (running != null)
            return running;

        string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Roblox", "Versions");
        if (Directory.Exists(root))
        {
            var dirs = Directory.GetDirectories(root, "version-*");
            Array.Sort(dirs);
            if (dirs.Length > 0)
                return Path.Combine(dirs[dirs.Length - 1], "RobloxPlayerBeta.exe");
        }
        return null;
    }

    private static int FindPid()
    {
        Process[] all = Process.GetProcessesByName("RobloxPlayerBeta");
        return all.Length == 0 ? 0 : all[0].Id;
    }

    private static bool Attach()
    {
        int pid = FindPid();
        if (pid == 0)
        {
            Console.WriteLine("RobloxPlayerBeta.exe is not running.");
            return false;
        }
        _mem = new Mem();
        _mem.Handle = OpenProcess(0x0010 | 0x1000, false, pid); // VM_READ | QUERY_LIMITED_INFORMATION
        if (_mem.Handle == IntPtr.Zero)
        {
            Console.WriteLine("OpenProcess failed: " + Marshal.GetLastWin32Error());
            return false;
        }
        bool wow;
        IsWow64Process(_mem.Handle, out wow);
        Console.WriteLine("pid=" + pid + " wow64=" + wow);

        var mods = new IntPtr[2048];
        int needed;
        if (!EnumProcessModulesEx(_mem.Handle, mods, mods.Length * IntPtr.Size, out needed, 0x03))
        {
            Console.WriteLine("EnumProcessModulesEx failed");
            return false;
        }
        int count = needed / IntPtr.Size;
        for (int i = 0; i < count; i++)
        {
            var sb = new StringBuilder(260);
            GetModuleBaseNameW(_mem.Handle, mods[i], sb, 260);
            string name = sb.ToString();
            if (!name.StartsWith("RobloxPlayerBeta", StringComparison.OrdinalIgnoreCase))
                continue;
            ModuleInfo mi;
            GetModuleInformation(_mem.Handle, mods[i], out mi, Marshal.SizeOf(typeof(ModuleInfo)));
            Console.WriteLine(string.Format("module {0,-24} base=0x{1:X} size=0x{2:X}", name, mi.Base.ToInt64(), mi.Size));
            if (name.Equals("RobloxPlayerBeta.exe", StringComparison.OrdinalIgnoreCase))
            {
                _mem.Base = (ulong)mi.Base.ToInt64();
                _mem.Size = mi.Size;
                _exePath = Process.GetProcessById(pid).Modules[i].FileName;
            }
        }
        if (_mem.Base == 0)
        {
            Console.WriteLine("RobloxPlayerBeta.exe module not found");
            return false;
        }
        Console.WriteLine(string.Format("exe base=0x{0:X} end=0x{1:X}", _mem.Base, _mem.Base + _mem.Size));
        return true;
    }

    private static string Within(ulong addr)
    {
        if (addr >= _mem.Base && addr < _mem.Base + _mem.Size)
            return string.Format("in-exe(+0x{0:X})", addr - _mem.Base);
        return "out-of-exe";
    }

    private static void DumpChain(ulong veGlobal, ulong fdmGlobal)
    {
        ulong ve = _mem.U64(veGlobal);
        Console.WriteLine(string.Format("\n[globals] VE@0x{0:X} -> 0x{1:X} ({2})", veGlobal, ve, Within(ve)));
        Console.WriteLine(string.Format("[globals] FDM@0x{0:X} -> 0x{1:X} ({2})", fdmGlobal, _mem.U64(fdmGlobal), Within(_mem.U64(fdmGlobal))));
        if (ve == 0)
            return;
        ulong fdmFromVe = _mem.U64(ve + (ulong)VisualEngineFakeDataModel);
        Console.WriteLine(string.Format("  VE+0x{0:X} -> FDM 0x{1:X} ({2})", VisualEngineFakeDataModel, fdmFromVe, Within(fdmFromVe)));
        ulong dm = _mem.U64(fdmFromVe + (ulong)FakeDataModelRealDataModel);
        Console.WriteLine(string.Format("  FDM+0x{0:X} -> DataModel 0x{1:X} ({2})", FakeDataModelRealDataModel, dm, Within(dm)));
        if (dm == 0)
            return;
        Console.WriteLine("  DataModel.Name = " + (_mem.Name(dm) ?? "<bad>"));
        Console.WriteLine(string.Format("  DataModel.GameLoaded = {0}", _mem.I32(dm + (ulong)DataModelGameLoaded)));
        ulong ws = _mem.U64(dm + (ulong)DataModelWorkspace);
        Console.WriteLine(string.Format("  Workspace 0x{0:X} name='{1}'", ws, _mem.Name(ws) ?? "<bad>"));
        if (ws != 0)
        {
            ulong cam = _mem.U64(ws + (ulong)WorkspaceCurrentCamera);
            Console.WriteLine(string.Format("  CurrentCamera 0x{0:X}", cam));
            if (cam != 0)
            {
                float[] pos = _mem.Floats(cam + (ulong)CameraPosition, 3);
                float[] rot = _mem.Floats(cam + (ulong)CameraRotation, 9);
                float fov = _mem.F32(cam + (ulong)CameraFov);
                float[] vp = _mem.Floats(cam + (ulong)CameraViewportSize, 2);
                if (pos != null) Console.WriteLine(string.Format("  camera.pos = {0:F2}, {1:F2}, {2:F2}", pos[0], pos[1], pos[2]));
                if (rot != null) Console.WriteLine(string.Format("  camera.rot = [{0:F3} {1:F3} {2:F3}] [{3:F3} {4:F3} {5:F3}] [{6:F3} {7:F3} {8:F3}]", rot[0], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8]));
                Console.WriteLine(string.Format("  camera.fov = {0:F2}  viewport = {1:F0}x{2:F0}", fov, vp == null ? 0 : vp[0], vp == null ? 0 : vp[1]));
            }
        }
        if (ve != 0)
        {
            float[] vm = _mem.Floats(ve + (ulong)VisualEngineViewMatrix, 16);
            if (vm != null)
            {
                Console.WriteLine("  ViewMatrix:");
                for (int r = 0; r < 4; r++)
                    Console.WriteLine(string.Format("    {0,9:F3} {1,9:F3} {2,9:F3} {3,9:F3}", vm[r * 4], vm[r * 4 + 1], vm[r * 4 + 2], vm[r * 4 + 3]));
            }
            float[] dims = _mem.Floats(ve + (ulong)VisualEngineDimensions, 2);
            if (dims != null)
                Console.WriteLine(string.Format("  VE.Dimensions = {0:F0}x{1:F0}", dims[0], dims[1]));
        }
    }

    private static void DumpPlayers(ulong dm)
    {
        ulong ws = _mem.U64(dm + (ulong)DataModelWorkspace);
        Console.WriteLine("\n[children of DataModel] name='" + (_mem.Name(dm) ?? "?") + "'");
        List<ulong> dmKids = _mem.Children(dm);
        Console.WriteLine("  count=" + dmKids.Count);
        ulong players = 0;
        foreach (ulong kid in dmKids)
        {
            string n = _mem.Name(kid);
            Console.WriteLine(string.Format("  0x{0:X}  {1}", kid, n ?? "<bad name>"));
            if (n == "Players")
                players = kid;
        }
        if (players == 0)
        {
            Console.WriteLine("Players service not found among DataModel children");
            return;
        }
        ulong local = _mem.U64(players + (ulong)PlayerLocalPlayer);
        Console.WriteLine(string.Format("\n[Players] 0x{0:X}  localPlayer=0x{1:X} name='{2}'", players, local, _mem.Name(local) ?? "?"));
        List<ulong> list = _mem.Children(players);
        Console.WriteLine("  children=" + list.Count);
        int shown = 0;
        foreach (ulong p in list)
        {
            if (shown++ >= 12) break;
            string pname = _mem.Name(p);
            ulong model = _mem.U64(p + (ulong)PlayerModelInstance);
            int uid = _mem.I32(p + (ulong)PlayerUserId);
            ulong team = _mem.U64(p + (ulong)PlayerTeam);
            Console.WriteLine(string.Format("  player 0x{0:X} name='{1}' userId={2} model=0x{3:X} team=0x{4:X}{5}",
                p, pname ?? "?", uid, model, team, p == local ? "  <LOCAL>" : ""));
            if (model == 0)
                continue;
            ulong hum = _mem.FindChild(model, "Humanoid");
            ulong head = _mem.FindChild(model, "Head");
            ulong root = _mem.FindChild(model, "HumanoidRootPart");
            Console.WriteLine(string.Format("    model children={0} humanoid=0x{1:X} head=0x{2:X} root=0x{3:X}",
                _mem.Children(model).Count, hum, head, root));
            if (hum != 0)
            {
                Console.WriteLine(string.Format("    hp={0:F1}/{1:F1} rootPart=0x{2:X}",
                    _mem.F32(hum + (ulong)HumanoidHealth), _mem.F32(hum + (ulong)HumanoidMaxHealth),
                    _mem.U64(hum + (ulong)HumanoidRootPart)));
            }
            foreach (ulong part in new ulong[] { head, root })
            {
                if (part == 0) continue;
                ulong prim = _mem.U64(part + (ulong)BasePartPrimitive);
                if (prim == 0) continue;
                float[] pos = _mem.Floats(prim + (ulong)PrimitivePosition, 3);
                float[] sz = _mem.Floats(prim + (ulong)PrimitiveSize, 3);
                if (pos != null)
                    Console.WriteLine(string.Format("    part '{0}' pos={1:F2},{2:F2},{3:F2} size={4:F2},{5:F2},{6:F2}",
                        _mem.Name(part), pos[0], pos[1], pos[2], sz == null ? 0 : sz[0], sz == null ? 0 : sz[1], sz == null ? 0 : sz[2]));
            }
        }
        GC.KeepAlive(ws);
    }

    private struct Section
    {
        public string Name;
        public ulong Va;
        public ulong VSize;
        public bool Writable;
    }

    // Section table read from the live module header (WindowsApps clients deny file access).
    private static List<Section> ReadSections(ulong moduleBase)
    {
        var res = new List<Section>();
        var hdr = new byte[0x1000];
        if (!_mem.Read(moduleBase, hdr))
            return res;
        int pe = BitConverter.ToInt32(hdr, 0x3C);
        if (pe <= 0 || pe + 24 > hdr.Length)
            return res;
        ushort nsec = BitConverter.ToUInt16(hdr, pe + 6);
        ushort optSize = BitConverter.ToUInt16(hdr, pe + 20);
        int secStart = pe + 24 + optSize;
        for (int i = 0; i < nsec; i++)
        {
            int o = secStart + i * 40;
            if (o + 40 > hdr.Length)
                break;
            string name = Encoding.ASCII.GetString(hdr, o, 8).TrimEnd('\0');
            uint vsize = BitConverter.ToUInt32(hdr, o + 8);
            uint va = BitConverter.ToUInt32(hdr, o + 12);
            uint chars = BitConverter.ToUInt32(hdr, o + 36);
            res.Add(new Section
            {
                Name = name,
                Va = va,
                VSize = vsize,
                Writable = (chars & 0x80000000) != 0
            });
        }
        return res;
    }

    private static void Discover()
    {
        List<Section> sections = ReadSections(_mem.Base);
        Console.WriteLine("\n[discover] sections from " + _exePath);
        foreach (Section s in sections)
            Console.WriteLine(string.Format("  {0,-10} va=0x{1:X} vsize=0x{2:X} writable={3}", s.Name, s.Va, s.VSize, s.Writable));

        var hits = new List<string>();
        foreach (Section s in sections)
        {
            if (!s.Writable || s.VSize < 8 || s.VSize > 64UL * 1024 * 1024)
                continue;
            int chunkBytes = 4 * 1024 * 1024;
            for (ulong done = 0; done < s.VSize; done += (ulong)chunkBytes)
            {
                int len = (int)Math.Min((ulong)chunkBytes, s.VSize - done);
                var buf = new byte[len];
                if (!_mem.Read(_mem.Base + s.Va + done, buf))
                    continue;
                for (int off = 0; off + 8 <= len; off += 8)
                {
                    ulong candidate = BitConverter.ToUInt64(buf, off);
                    if (candidate < MinPtr || candidate > MaxPtr || (candidate & 7) != 0)
                        continue;
                    ulong slot = _mem.Base + s.Va + done + (ulong)off;
                    ulong fdm = candidate;
                    ulong dm = _mem.U64(fdm + (ulong)FakeDataModelRealDataModel);
                    if (!_mem.Plausible(dm))
                        continue;
                    ulong ws = _mem.U64(dm + (ulong)DataModelWorkspace);
                    if (!_mem.Plausible(ws))
                        continue;
                    string wsName = _mem.Name(ws);
                    if (wsName != "Workspace")
                        continue;
                    ulong players = _mem.FindChild(dm, "Players");
                    string line = string.Format(
                        "GLOBAL slot=0x{0:X} rva=0x{1:X} fakeDM=0x{2:X} realDM=0x{3:X} ws=0x{4:X} players=0x{5:X} local=0x{6:X} dmName='{7}'",
                        slot, slot - _mem.Base, fdm, dm, ws, players,
                        players == 0 ? 0 : _mem.U64(players + (ulong)PlayerLocalPlayer), _mem.Name(dm) ?? "?");
                    Console.WriteLine(line);
                    hits.Add(line);
                }
            }
        }

        // Find VisualEngine candidates pointing at each verified FakeDataModel.
        var fdms = new HashSet<ulong>();
        foreach (string line in hits)
        {
            int i = line.IndexOf("fakeDM=0x", StringComparison.Ordinal);
            if (i < 0) continue;
            int start = i + 9;
            int end = line.IndexOf(' ', start);
            ulong v = Convert.ToUInt64(line.Substring(start, end - start), 16);
            fdms.Add(v);
        }
        foreach (Section s in sections)
        {
            if (!s.Writable || s.VSize < 8 || s.VSize > 64UL * 1024 * 1024)
                continue;
            int chunkBytes = 4 * 1024 * 1024;
            for (ulong done = 0; done < s.VSize; done += (ulong)chunkBytes)
            {
                int len = (int)Math.Min((ulong)chunkBytes, s.VSize - done);
                var buf = new byte[len];
                if (!_mem.Read(_mem.Base + s.Va + done, buf))
                    continue;
                for (int off = 0; off + 8 <= len; off += 8)
                {
                    ulong candidate = BitConverter.ToUInt64(buf, off);
                    if (candidate < MinPtr || candidate > MaxPtr || (candidate & 7) != 0)
                        continue;
                    ulong fdm = _mem.U64(candidate + (ulong)VisualEngineFakeDataModel);
                    if (!fdms.Contains(fdm))
                        continue;
                    float[] vm = _mem.Floats(candidate + (ulong)VisualEngineViewMatrix, 16);
                    if (vm == null)
                        continue;
                    bool finite = true;
                    for (int k = 0; k < 16; k++)
                        if (float.IsNaN(vm[k]) || float.IsInfinity(vm[k]) || Math.Abs(vm[k]) > 100000.0f)
                            finite = false;
                    if (!finite)
                        continue;
                    ulong slot = _mem.Base + s.Va + done + (ulong)off;
                    string line = string.Format("VISUAL_ENGINE slot=0x{0:X} rva=0x{1:X} ve=0x{2:X} fakeDM=0x{3:X}", slot, slot - _mem.Base, candidate, fdm);
                    Console.WriteLine(line);
                    hits.Add(line);
                }
            }
        }
        Console.WriteLine("discover hits=" + hits.Count);
        try
        {
            string outPath = Path.Combine(Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName) ?? ".", "probe_discovery.txt");
            File.WriteAllLines(outPath, hits.ToArray());
            Console.WriteLine("written " + outPath);
        }
        catch (Exception ex)
        {
            Console.WriteLine("could not write discovery file: " + ex.Message);
        }
    }

    public static int Main(string[] args)
    {
        Console.WriteLine("rbx_esp probe — offsets " + ProfileVersion);
        _exePath = VersionFolder();
        Console.WriteLine("client exe: " + (_exePath ?? "<not found>"));
        if (_exePath != null && File.Exists(_exePath))
        {
            var vi = FileVersionInfo.GetVersionInfo(_exePath);
            Console.WriteLine("file version: " + vi.FileVersion + "  product: " + vi.ProductVersion);
        }
        if (!Attach())
            return 2;

        ulong veGlobal = _mem.Base + VisualEnginePointer;
        ulong fdmGlobal = _mem.Base + FakeDataModelPointer;
        DumpChain(veGlobal, fdmGlobal);

        ulong dm = 0;
        ulong ve = _mem.U64(veGlobal);
        if (ve != 0)
            dm = _mem.U64(_mem.U64(ve + (ulong)VisualEngineFakeDataModel) + (ulong)FakeDataModelRealDataModel);
        if (dm == 0)
        {
            ulong fdm = _mem.U64(fdmGlobal);
            if (fdm != 0)
                dm = _mem.U64(fdm + (ulong)FakeDataModelRealDataModel);
        }
        if (dm != 0 && _mem.Plausible(dm))
            DumpPlayers(dm);
        else
            Console.WriteLine("\n[chain] no usable DataModel from profile globals — run --discover");

        if (args.Length > 0 && args[0] == "--discover")
            Discover();

        CloseHandle(_mem.Handle);
        return 0;
    }
}
