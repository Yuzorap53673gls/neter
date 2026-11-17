# ui_probe.ps1 — posts synthetic mouse input to the rbx_esp input proxy.
#
# Nothing here moves the physical cursor or clicks another application: the
# messages are delivered straight to the proxy HWND that covers the panel.
# Used by the verification pass for tabs, switches, sliders, window buttons,
# scrolling and the click-through hit test.
#
#   state                               show windows, styles, alpha, hit test
#   click <screenX> <screenY>           move + left click at a screen point
#   wheel <screenX> <screenY> <delta>   wheel over the panel, delta in notches
#   hittest <screenX> <screenY>         WindowFromPoint + class at a point

param(
    [Parameter(Mandatory = $true)][string]$Action,
    [int]$X = 0,
    [int]$Y = 0,
    [int]$Delta = -1
)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32Probe {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern bool FindWindow(string cls, string title);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")]
    public static extern int GetClassName(IntPtr hwnd, StringBuilder buffer, int size);
    [DllImport("user32.dll")]
    public static extern IntPtr PostMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")]
    public static extern bool ScreenToClient(IntPtr hwnd, ref POINT point);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowLongPtr(IntPtr hwnd, int index);
    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")]
    public static extern bool GetLayeredWindowAttributes(IntPtr hwnd, out uint color, out byte alpha, out uint flags);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

$GWL_EXSTYLE = -20
$WS_EX_TRANSPARENT = 0x00000020
$WS_EX_LAYERED = 0x00080000
$WS_EX_TOPMOST = 0x00000008
$WM_MOUSEMOVE = 0x0200
$WM_LBUTTONDOWN = 0x0201
$WM_LBUTTONUP = 0x0202
$WM_MOUSEWHEEL = 0x020A
$WM_NCHITTEST = 0x0084

$proxy = [IntPtr]::Zero
$render = [IntPtr]::Zero
$found = New-Object 'System.Collections.Generic.List[object]'
$callback = [Win32Probe+EnumProc]{
    param([IntPtr]$hwnd, [IntPtr]$param)
    $buffer = New-Object System.Text.StringBuilder 128
    [Win32Probe]::GetClassName($hwnd, $buffer, $buffer.Capacity) | Out-Null
    $name = $buffer.ToString()
    if ($name -eq 'RbxEspOverlayInput') { $script:proxy = $hwnd }
    if ($name -eq 'RbxEspOverlayRender') { $script:render = $hwnd }
    return $true
}
[Win32Probe]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null

function Get-Rect($hwnd) {
    $rect = New-Object Win32Probe+RECT
    [Win32Probe]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    return $rect
}

function Get-ClassName($hwnd) {
    $buffer = New-Object System.Text.StringBuilder 128
    [Win32Probe]::GetClassName($hwnd, $buffer, $buffer.Capacity) | Out-Null
    return $buffer.ToString()
}

function Click-Point([int]$sx, [int]$sy) {
    $point = New-Object Win32Probe+POINT
    $point.X = $sx
    $point.Y = $sy
    [Win32Probe]::ScreenToClient($proxy, [ref]$point) | Out-Null
    $lp = ($point.Y -shl 16) -bor ($point.X -band 0xFFFF)
    [Win32Probe]::PostMessage($proxy, $WM_MOUSEMOVE, [IntPtr]::Zero, [IntPtr]$lp) | Out-Null
    Start-Sleep -Milliseconds 60
    [Win32Probe]::PostMessage($proxy, $WM_LBUTTONDOWN, [IntPtr]1, [IntPtr]$lp) | Out-Null
    Start-Sleep -Milliseconds 120
    [Win32Probe]::PostMessage($proxy, $WM_LBUTTONUP, [IntPtr]0, [IntPtr]$lp) | Out-Null
    Start-Sleep -Milliseconds 220
}

function Wheel-Point([int]$sx, [int]$sy, [int]$notches) {
    $screen = ($sy -shl 16) -bor ($sx -band 0xFFFF)
    $wparam = (($notches * 120) -band 0xFFFF) -shl 16
    [Win32Probe]::PostMessage($proxy, $WM_MOUSEWHEEL, [IntPtr]$wparam, [IntPtr]$screen) | Out-Null
    Start-Sleep -Milliseconds 250
}

if (-not $proxy) {
    Write-Output "proxy: not found"
    exit 2
}

switch ($Action) {
    'state' {
        $pr = Get-Rect $proxy
        $rr = Get-Rect $render
        $exProxy = [Win32Probe]::GetWindowLongPtr($proxy, $GWL_EXSTYLE).ToInt64()
        $exRender = [Win32Probe]::GetWindowLongPtr($render, $GWL_EXSTYLE).ToInt64()
        $color = 0
        $alpha = 0
        $flags = 0
        [Win32Probe]::GetLayeredWindowAttributes($proxy, [ref]$color, [ref]$alpha, [ref]$flags) | Out-Null
        Write-Output ("proxy rect={0},{1},{2},{3} class={4} ex=0x{5:X} layered={6} topmost={7} alpha={8}" -f `
            $pr.Left, $pr.Top, $pr.Right, $pr.Bottom, (Get-ClassName $proxy), $exProxy, `
            [bool]($exProxy -band $WS_EX_LAYERED), [bool]($exProxy -band $WS_EX_TOPMOST), $alpha)
        Write-Output ("render rect={0},{1},{2},{3} class={4} ex=0x{5:X} transparent={6} topmost={7}" -f `
            $rr.Left, $rr.Top, $rr.Right, $rr.Bottom, (Get-ClassName $render), $exRender, `
            [bool]($exRender -band $WS_EX_TRANSPARENT), [bool]($exRender -band $WS_EX_TOPMOST))

        $hit = [Win32Probe]::SendMessage($render, $WM_NCHITTEST, [IntPtr]::Zero, [IntPtr]::Zero)
        Write-Output ("render WM_NCHITTEST -> {0} (HTTRANSPARENT=-1)" -f $hit.ToInt64())

        $inside = New-Object Win32Probe+POINT
        $inside.X = [int](($pr.Left + $pr.Right) / 2)
        $inside.Y = [int](($pr.Top + $pr.Bottom) / 2)
        $hwndInside = [Win32Probe]::WindowFromPoint($inside)
        Write-Output ("WindowFromPoint inside panel ({0},{1}) -> class={2} hwnd=0x{3:X}" -f `
            $inside.X, $inside.Y, (Get-ClassName $hwndInside), $hwndInside.ToInt64())

        $outside = New-Object Win32Probe+POINT
        $outside.X = 60
        $outside.Y = 60
        $hwndOutside = [Win32Probe]::WindowFromPoint($outside)
        $outsideClass = Get-ClassName $hwndOutside
        Write-Output ("WindowFromPoint outside panel (60,60) -> class={0} hwnd=0x{1:X}" -f `
            $outsideClass, $hwndOutside.ToInt64())
        if ($outsideClass -eq 'RbxEspOverlayRender' -or $outsideClass -eq 'RbxEspOverlayInput') {
            Write-Output "click-through: FAIL (overlay intercepted the outside point)"
        } else {
            Write-Output "click-through: PASS (outside point belongs to another window)"
        }
    }
    'click' { Click-Point $X $Y }
    'wheel' { Wheel-Point $X $Y $Delta }
    'hittest' {
        $point = New-Object Win32Probe+POINT
        $point.X = $X
        $point.Y = $Y
        $hwnd = [Win32Probe]::WindowFromPoint($point)
        Write-Output ("WindowFromPoint ({0},{1}) -> class={2} hwnd=0x{3:X}" -f `
            $X, $Y, (Get-ClassName $hwnd), $hwnd.ToInt64())
    }
    default { Write-Output "unknown action: $Action"; exit 1 }
}
