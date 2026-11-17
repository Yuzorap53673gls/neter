// log.h — timestamped diagnostics with per-key throttling.

#pragma once

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <mutex>
#include <chrono>

class Log {
public:
    static Log& get();

    bool open(const wchar_t* path);
    void close();

    void info(const char* fmt, ...);
    void warn(const char* fmt, ...);
    void error(const char* fmt, ...);

    // Emits at most one message per `interval_ms` for the given key.
    void throttled(const char* key, uint32_t interval_ms, const char* fmt, ...);

    bool is_open() const;
    const std::wstring& path() const;

    // The log stream is narrow. Wide paths and names are converted to UTF-8
    // before formatting so %ls is never used with the CRT's narrow printf,
    // which depends on the process locale.
    static std::string utf8(const std::wstring& text);
    static std::string utf8(const wchar_t* text);

private:
    Log() = default;
    void write_line(const char* level, const std::string& text);
    void vwrite(const char* level, const char* fmt, va_list args);

    mutable std::mutex mutex_;
    std::FILE* file_ = nullptr;
    std::wstring path_;
    std::unordered_map<std::string, std::chrono::steady_clock::time_point> throttle_;
};
