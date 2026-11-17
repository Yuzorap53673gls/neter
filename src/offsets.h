// offsets.h — Roblox external ESP offset profile.
//
// Every constant below comes literally from the RbxDumperV2 dump listed in
// kProfileVersion. Nothing here is guessed. The application refuses to use this
// profile when the installed client does not match kProfileVersion; see
// offsets_trusted() in game.cpp.
//
// When a new dump arrives, replace the constants and kProfileVersion together.
// Never mix constants from two builds.

#pragma once

#include <cstdint>

namespace off {

inline constexpr const char* kProfileVersion = "version-11f155f3450f4c8e";
inline constexpr const char* kProfileSource = "RbxDumperV2 dump 2026-10-15";
inline constexpr const char* kBuildId = "rbx_esp 1.0.0";

// Pointer limits accepted for any value read from the target.
inline constexpr uint64_t kMinPtr = 0x10000;
inline constexpr uint64_t kMaxPtr = 0x7FFFFFFEFFFFull;

// ---- VisualEngine -------------------------------------------------------
inline constexpr uint64_t VisualEngine_Pointer = 0x884C2E0;
inline constexpr uint32_t VisualEngine_Dimensions = 0xB10;
inline constexpr uint32_t VisualEngine_ViewMatrix = 0x1B0;
inline constexpr uint32_t VisualEngine_RenderView = 0xC38;
inline constexpr uint32_t VisualEngine_FakeDataModel = 0xAF0;

// ---- FakeDataModel ------------------------------------------------------
inline constexpr uint64_t FakeDataModel_Pointer = 0x8DC8000;
inline constexpr uint32_t FakeDataModel_RealDataModel = 0x1F8;

// ---- Instance -----------------------------------------------------------
inline constexpr uint32_t Instance_NameContainer = 0x70;
inline constexpr uint32_t Instance_Name = 0x8;
inline constexpr uint32_t Instance_ChildrenStart = 0x78;
inline constexpr uint32_t Instance_ChildrenEnd = 0x8;
inline constexpr uint32_t Instance_Parent = 0x68;
inline constexpr uint32_t Instance_ChildStride = 0x10;
inline constexpr uint32_t String_Length = 0x10;

// ---- DataModel ----------------------------------------------------------
inline constexpr uint32_t DataModel_GameLoaded = 0x5D0;
inline constexpr uint32_t DataModel_Workspace = 0x150;
inline constexpr uint32_t DataModel_PlaceId = 0x188;
inline constexpr uint32_t DataModel_GameId = 0x180;
inline constexpr uint32_t DataModel_JobId = 0x110;
inline constexpr uint32_t DataModel_PlaceVersion = 0x1A4;

// ---- Workspace / Camera -------------------------------------------------
inline constexpr uint32_t Workspace_CurrentCamera = 0x4A8;
inline constexpr uint32_t Workspace_DistributedGameTime = 0x4C8;

inline constexpr uint32_t Camera_Position = 0xEC;
inline constexpr uint32_t Camera_Rotation = 0xC8;
inline constexpr uint32_t Camera_FieldOfView = 0x130;
inline constexpr uint32_t Camera_ViewportSize = 0x2CC;
inline constexpr uint32_t Camera_CameraType = 0x128;
inline constexpr uint32_t Camera_CameraSubject = 0xB8;

// ---- Player -------------------------------------------------------------
inline constexpr uint32_t Player_LocalPlayer = 0x120;
inline constexpr uint32_t Player_UserId = 0xC0;
inline constexpr uint32_t Player_DisplayName = 0x128;
inline constexpr uint32_t Player_ModelInstance = 0x298;
inline constexpr uint32_t Player_Team = 0x2D8;
inline constexpr uint32_t Player_TeamColor = 0x3B0;
inline constexpr uint32_t Player_AccountAge = 0x35C;

inline constexpr uint32_t Team_BrickColor = 0xA8;

// ---- Humanoid -----------------------------------------------------------
inline constexpr uint32_t Humanoid_Health = 0x18C;
inline constexpr uint32_t Humanoid_MaxHealth = 0x1A4;
inline constexpr uint32_t Humanoid_DisplayName = 0xA8;
inline constexpr uint32_t Humanoid_RigType = 0x1BC;
inline constexpr uint32_t Humanoid_HumanoidRootPart = 0x468;
inline constexpr uint32_t Humanoid_SeatPart = 0xF8;
inline constexpr uint32_t Humanoid_JumpPower = 0x1A0;
inline constexpr uint32_t Humanoid_Walkspeed = 0x1CC;

// ---- BasePart / Primitive ----------------------------------------------
inline constexpr uint32_t BasePart_Primitive = 0x180;
inline constexpr uint32_t BasePart_Transparency = 0x120;
inline constexpr uint32_t BasePart_Color3 = 0x1AC;
inline constexpr uint32_t BasePart_Shape = 0x1A8;

inline constexpr uint32_t Primitive_Position = 0xD4;
inline constexpr uint32_t Primitive_Rotation = 0xB0;
inline constexpr uint32_t Primitive_Size = 0x1C4;
inline constexpr uint32_t Primitive_Owner = 0x218;
inline constexpr uint32_t Primitive_Validate = 0x6;

// ---- Model / Attachment -------------------------------------------------
inline constexpr uint32_t Model_PrimaryPart = 0x248;
inline constexpr uint32_t Model_Scale = 0x134;
inline constexpr uint32_t Attachment_Position = 0xB4;

} // namespace off
