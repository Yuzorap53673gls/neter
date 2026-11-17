// memory.cpp — PROCESS_VM_READ only. No write API is imported anywhere.

#include "memory.h"

#include "log.h"

#include <psapi.h>
#include <algorithm>
#include <cstring>
#include <cwchar>

#pragma comment(lib, "psapi.lib")

Memory::~Memory() {
    detach();
}

void Memory::detach() {
    if (process_) {
        CloseHandle(process_);
        process_ = nullptr;
    }
    pid_ = 0;
    base_ = 0;
    size_ = 0;
}

bool Memory::attach(uint32_t pid) {
    detach();
    if (pid == 0)
        return false;

    // Read-only access. PROCESS_QUERY_INFORMATION is required for module info.
    process_ = OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (!process_) {
        Log::get().warn("OpenProcess(PROCESS_VM_READ|PROCESS_QUERY_INFORMATION) failed for pid %u (win32 %lu)", pid,
                        GetLastError());
        return false;
    }

    HMODULE modules[1024];
    DWORD needed = 0;
    if (!EnumProcessModulesEx(process_, modules, sizeof(modules), &needed, LIST_MODULES_ALL)) {
        Log::get().warn("EnumProcessModulesEx failed (win32 %lu)", GetLastError());
        detach();
        return false;
    }

    const size_t count = needed / sizeof(HMODULE);
    for (size_t i = 0; i < count; ++i) {
        wchar_t name[MAX_PATH] = {};
        if (!GetModuleBaseNameW(process_, modules[i], name, MAX_PATH))
            continue;
        if (_wcsicmp(name, L"RobloxPlayerBeta.exe") != 0)
            continue;

        MODULEINFO info{};
        if (!GetModuleInformation(process_, modules[i], &info, sizeof(info)))
            continue;
        base_ = reinterpret_cast<uint64_t>(info.lpBaseOfDll);
        size_ = info.SizeOfImage;
        module_name_ = name;
        pid_ = pid;
        Log::get().info("attached pid=%u module=%s base=0x%llX size=0x%llX", pid_, Log::utf8(module_name_).c_str(),
                        static_cast<unsigned long long>(base_), static_cast<unsigned long long>(size_));
        return true;
    }

    Log::get().warn("RobloxPlayerBeta.exe module not present in pid %u (ambiguous prefix matches rejected)", pid);
    detach();
    return false;
}

bool Memory::read(uint64_t address, void* buffer, size_t size) const {
    if (!process_ || !buffer || size == 0)
        return false;
    if (address < off::kMinPtr || address > off::kMaxPtr)
        return false;
    if (size > off::kMaxPtr || address + size > off::kMaxPtr)
        return false;

    SIZE_T got = 0;
    const BOOL ok = ReadProcessMemory(process_, reinterpret_cast<LPCVOID>(address), buffer, size, &got);
    return ok && got == size;
}

uint64_t Memory::read_ptr(uint64_t address) const {
    uint64_t value = 0;
    return read(address, value) ? value : 0;
}

int32_t Memory::read_i32(uint64_t address) const {
    int32_t value = 0;
    return read(address, value) ? value : 0;
}

float Memory::read_f32(uint64_t address) const {
    float value = 0.0f;
    return read(address, value) ? value : 0.0f;
}

Vec3 Memory::read_vec3(uint64_t address) const {
    Vec3 value{};
    read(address, &value, sizeof(value));
    return value;
}

bool Memory::read_floats(uint64_t address, float* out, size_t count) const {
    return out && count > 0 && read(address, out, count * sizeof(float));
}

bool Memory::plausible(uint64_t pointer) {
    return pointer >= off::kMinPtr && pointer <= off::kMaxPtr && (pointer & 3) == 0;
}

std::string Memory::read_name(uint64_t instance) const {
    if (!plausible(instance))
        return {};
    const uint64_t container = read_ptr(instance + off::Instance_NameContainer);
    if (!plausible(container))
        return {};

    const int32_t length = read_i32(container + off::String_Length);
    if (length <= 0 || length > 200)
        return {};

    uint64_t data = 0;
    if (length <= 15) {
        // Small-string optimisation: bytes live inline at container + 0x8.
        data = container + off::Instance_Name;
    } else {
        data = read_ptr(container + off::Instance_Name);
        if (!plausible(data))
            return {};
    }

    char buffer[201] = {};
    if (!read(data, buffer, static_cast<size_t>(length)))
        return {};
    if (std::memchr(buffer, '\0', static_cast<size_t>(length)) != nullptr)
        return {};

    std::string name(buffer, static_cast<size_t>(length));
    for (unsigned char c : name) {
        if (c < 0x20 && c != '\t')
            return {};
    }
    return name;
}

std::vector<uint64_t> Memory::read_children(uint64_t instance, size_t limit) const {
    std::vector<uint64_t> result;
    if (!plausible(instance))
        return result;

    const uint64_t descriptor = read_ptr(instance + off::Instance_ChildrenStart);
    if (!plausible(descriptor))
        return result;

    const uint64_t begin = read_ptr(descriptor);
    const uint64_t end = read_ptr(descriptor + off::Instance_ChildrenEnd);
    if (!plausible(begin) || !plausible(end) || end < begin)
        return result;

    const uint64_t bytes = end - begin;
    const uint64_t stride = off::Instance_ChildStride;
    if (bytes == 0 || bytes % stride != 0)
        return result;

    const uint64_t count = bytes / stride;
    if (count == 0 || count > limit)
        return result;

    std::vector<uint8_t> raw(static_cast<size_t>(bytes));
    if (!read(begin, raw.data(), raw.size()))
        return result;

    result.reserve(static_cast<size_t>(count));
    for (uint64_t i = 0; i < count; ++i) {
        uint64_t child = 0;
        std::memcpy(&child, raw.data() + i * stride, sizeof(child));
        if (plausible(child))
            result.push_back(child);
    }
    return result;
}

uint64_t Memory::find_child(uint64_t parent, const std::string& name) const {
    for (uint64_t child : read_children(parent)) {
        if (read_name(child) == name)
            return child;
    }
    return 0;
}

bool Memory::child_vector_sane(uint64_t instance) const {
    if (!plausible(instance))
        return false;
    const uint64_t descriptor = read_ptr(instance + off::Instance_ChildrenStart);
    if (!plausible(descriptor))
        return false;
    const uint64_t begin = read_ptr(descriptor);
    const uint64_t end = read_ptr(descriptor + off::Instance_ChildrenEnd);
    if (!plausible(begin) || !plausible(end) || end < begin)
        return false;
    const uint64_t bytes = end - begin;
    return bytes > 0 && bytes % off::Instance_ChildStride == 0 && bytes <= 512 * off::Instance_ChildStride;
}
