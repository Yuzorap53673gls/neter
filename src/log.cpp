// log.cpp — file logging shared with read-only external tools.

#include "log.h"

#include <cstdio>
#include <ctime>
#include <share.h>
#include <windows.h>

Log& Log::get() {
    static Log instance;
    return instance;
}

bool Log::open(const wchar_t* path) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (file_)
        std::fclose(file_);
    path_ = path ? path : L"rbx_esp.log";

    // Plain append mode on purpose. The UCRT's ccs=UTF-8 mode makes the stream
    // wide-oriented, and the first narrow fprintf on it raises an invalid
    // parameter fast-fail (0xC0000409). The logger is narrow throughout, so the
    // mode stays plain and UTF-8 conversion happens before formatting.
    // _SH_DENYNO maps to FILE_SHARE_READ | FILE_SHARE_WRITE so the probe and
    // verify.ps1 can read the log while the application keeps writing.
    file_ = _wfsopen(path_.c_str(), L"a+", _SH_DENYNO);
    if (!file_)
        return false;
    std::setvbuf(file_, nullptr, _IOLBF, 8192);
    return true;
}

std::string Log::utf8(const std::wstring& text) {
    if (text.empty())
        return {};
    const int needed = WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0,
                                           nullptr, nullptr);
    if (needed <= 0)
        return {};
    std::string out(static_cast<size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), needed, nullptr,
                        nullptr);
    return out;
}

std::string Log::utf8(const wchar_t* text) {
    if (!text)
        return {};
    return utf8(std::wstring(text));
}

void Log::close() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (file_) {
        std::fclose(file_);
        file_ = nullptr;
    }
}

bool Log::is_open() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return file_ != nullptr;
}

const std::wstring& Log::path() const {
    return path_;
}

void Log::write_line(const char* level, const std::string& text) {
    if (!file_)
        return;

    SYSTEMTIME st;
    GetLocalTime(&st);
    std::fprintf(file_, "[%02u:%02u:%02u.%03u] %-5s %s\n", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
                 level, text.c_str());
    std::fflush(file_);
}

void Log::vwrite(const char* level, const char* fmt, va_list args) {
    char buffer[2048];
    vsnprintf(buffer, sizeof(buffer), fmt, args);
    write_line(level, buffer);
}

void Log::info(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    std::lock_guard<std::mutex> lock(mutex_);
    vwrite("INFO", fmt, args);
    va_end(args);
}

void Log::warn(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    std::lock_guard<std::mutex> lock(mutex_);
    vwrite("WARN", fmt, args);
    va_end(args);
}

void Log::error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    std::lock_guard<std::mutex> lock(mutex_);
    vwrite("ERROR", fmt, args);
    va_end(args);
}

void Log::throttled(const char* key, uint32_t interval_ms, const char* fmt, ...) {
    const auto now = std::chrono::steady_clock::now();
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = throttle_.find(key);
        if (it != throttle_.end()) {
            const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - it->second).count();
            if (elapsed < static_cast<int64_t>(interval_ms))
                return;
        }
        throttle_[key] = now;
    }
    va_list args;
    va_start(args, fmt);
    std::lock_guard<std::mutex> lock(mutex_);
    vwrite("WARN", fmt, args);
    va_end(args);
}
