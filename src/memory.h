// memory.h — read-only attachment to RobloxPlayerBeta.exe.

#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <windows.h>

#include "math3d.h"
#include "offsets.h"

class Memory {
public:
    Memory() = default;
    ~Memory();

    Memory(const Memory&) = delete;
    Memory& operator=(const Memory&) = delete;

    bool attach(uint32_t pid);
    void detach();

    bool attached() const { return process_ != nullptr; }
    HANDLE handle() const { return process_; }
    uint32_t pid() const { return pid_; }
    uint64_t module_base() const { return base_; }
    uint64_t module_size() const { return size_; }
    bool module_contains(uint64_t address) const {
        return address >= base_ && address < base_ + size_;
    }

    // Raw read. Fails without throwing on any invalid input.
    bool read(uint64_t address, void* buffer, size_t size) const;

    template <typename T>
    bool read(uint64_t address, T& out) const {
        return read(address, &out, sizeof(T));
    }

    uint64_t read_ptr(uint64_t address) const;
    int32_t read_i32(uint64_t address) const;
    float read_f32(uint64_t address) const;
    Vec3 read_vec3(uint64_t address) const;
    bool read_floats(uint64_t address, float* out, size_t count) const;

    static bool plausible(uint64_t pointer);

    // Roblox instance name. Handles both SSO (<=15 bytes) and heap strings.
    std::string read_name(uint64_t instance) const;

    // Vector descriptor: instance+0x78 -> descriptor; descriptor+0 -> begin,
    // descriptor+0x8 -> end; entries are 0x10 bytes with the pointer first.
    std::vector<uint64_t> read_children(uint64_t instance, size_t limit = 512) const;

    uint64_t find_child(uint64_t parent, const std::string& name) const;
    bool child_vector_sane(uint64_t instance) const;

    std::wstring module_name() const { return module_name_; }

private:
    HANDLE process_ = nullptr;
    uint32_t pid_ = 0;
    uint64_t base_ = 0;
    uint64_t size_ = 0;
    std::wstring module_name_ = L"RobloxPlayerBeta.exe";
};
