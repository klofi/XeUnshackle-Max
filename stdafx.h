// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently
//

#pragma once

#include <xtl.h>
#include <xboxmath.h>
#include <string>
#include <algorithm>
#include <xaudio2.h>
#include <xmedia2.h>
#include <AtgApp.h>
#include <AtgFont.h>
#include <AtgHelp.h>
#include <AtgInput.h>
#include <AtgResource.h>
#include <AtgUtil.h>

using namespace std;

// an intrinsic they left out...
#define __isync()        __emit(0x4C00012C)

// Bunch of this was taken from xkelib
// Should have just used that...

typedef struct _STRING {
	USHORT Length;
	USHORT MaximumLength;
	PCHAR Buffer;
} STRING, * PSTRING;

typedef struct _CSTRING {
	USHORT Length;
	USHORT MaximumLength;
	CONST char* Buffer;
} CSTRING, * PCSTRING;

typedef struct _UNICODE_STRING {
	USHORT Length;
	USHORT MaximumLength;
	PWSTR  Buffer;
} UNICODE_STRING, * PUNICODE_STRING;

typedef PSTRING			POBJECT_STRING;
typedef PSTRING			PANSI_STRING;
typedef CONST CHAR* PCSZ;

typedef struct _OBJECT_ATTRIBUTES {
	HANDLE RootDirectory;
	POBJECT_STRING ObjectName;
	ULONG Attributes;
} OBJECT_ATTRIBUTES, * POBJECT_ATTRIBUTES;

// returned by a call to 'NtQueryInformationFile' with 0x22 = FileNetworkOpenInformation
typedef struct _FILE_NETWORK_OPEN_INFORMATION {
	LARGE_INTEGER CreationTime; // 0x0 sz:0x8
	LARGE_INTEGER LastAccessTime; // 0x8 sz:0x8
	LARGE_INTEGER LastWriteTime; // 0x10 sz:0x8
	LARGE_INTEGER ChangeTime; // 0x18 sz:0x8
	LARGE_INTEGER AllocationSize; // 0x20 sz:0x8
	LARGE_INTEGER EndOfFile; // 0x28 sz:0x8
	DWORD FileAttributes; // 0x30 sz:0x4
} FILE_NETWORK_OPEN_INFORMATION, * PFILE_NETWORK_OPEN_INFORMATION; // size 56
C_ASSERT(sizeof(FILE_NETWORK_OPEN_INFORMATION) == 0x38);

// VOID InitializeObjectAttributes(
//     OUT POBJECT_ATTRIBUTES p,
//     IN STRING n,
//     IN ULONG a,
//     IN HANDLE r)
#define InitializeObjectAttributes( p, name, attrib, root){		\
	(p)->RootDirectory = root;                            \
	(p)->Attributes = attrib;                             \
	(p)->ObjectName = name;                               \
}

#define NT_SUCCESS(Status)              (((NTSTATUS)(Status)) >= 0)

/* description about xex exe headers in memory */
typedef struct _XBOX_HARDWARE_INFO {
	DWORD Flags;
	unsigned char NumberOfProcessors;
	unsigned char PCIBridgeRevisionID;
	unsigned char Reserved[6];
	unsigned short BldrMagic;
	unsigned short BldrFlags;
} XBOX_HARDWARE_INFO, * PXBOX_HARDWARE_INFO;

#define EXPORTNUM(x)

typedef long			NTSTATUS;

extern "C" {
	NTSYSAPI
		EXPORTNUM(177)
		BYTE
		NTAPI
		KfAcquireSpinLock(
			IN OUT	PDWORD spinVar
		);

	NTSYSAPI
		EXPORTNUM(180)
		VOID
		NTAPI
		KfReleaseSpinLock(
			IN OUT	PDWORD spinVar,
			IN		BYTE oldIrql
		);

	NTSYSAPI
		EXPORTNUM(190)
		PVOID
		NTAPI
		MmGetPhysicalAddress(
			IN		PVOID Address
		);

	EXPORTNUM(431)
		extern PCHAR ExLoadedImageName;

	// buffers are 0x10 bytes in length, on cmd that recv no response send NULL for recv
	NTSYSAPI
		EXPORTNUM(41)
		VOID
		NTAPI
		HalSendSMCMessage(
			IN		LPVOID pCommandBuffer,
			OUT		LPVOID pRecvBuffer
		);

	NTSYSAPI
		EXPORTNUM(409)
		NTSTATUS
		NTAPI
		XexLoadImage(
			IN		LPCSTR szXexName,
			IN		DWORD dwModuleTypeFlags,
			IN		DWORD dwMinimumVersion,
			IN OUT	PHANDLE pHandle
		);

	NTSYSAPI
		EXPORTNUM(13)
		DWORD
		NTAPI
		ExCreateThread(
			IN		PHANDLE pHandle,
			IN		DWORD dwStackSize,
			IN		LPDWORD lpThreadId,
			IN		PVOID apiThreadStartup,
			IN		LPTHREAD_START_ROUTINE lpStartAddress,
			IN		LPVOID lpParameter,
			IN		DWORD dwCreationFlagsMod
		);

	VOID XapiThreadStartup(
		IN		VOID(__cdecl* StartRoutine)(VOID*),
		IN		PVOID StartContext,
		IN		DWORD dwExitCode
	);

	EXPORTNUM(342)
		extern PXBOX_HARDWARE_INFO XboxHardwareInfo;

	NTSYSAPI
		EXPORTNUM(300)
		VOID
		NTAPI
		RtlInitAnsiString(
			IN OUT	PANSI_STRING DestinationString,
			IN		PCSZ  SourceString
		);

	NTSYSAPI
		EXPORTNUM(231)
		NTSTATUS
		NTAPI
		NtQueryFullAttributesFile(
			IN		POBJECT_ATTRIBUTES ObjectAttributes,
			OUT		PFILE_NETWORK_OPEN_INFORMATION Attributes
		);

	NTSYSAPI
		EXPORTNUM(410)
		NTSTATUS
		NTAPI
		XexLoadImageFromMemory(
			IN		PVOID pvXexBuffer,
			IN		DWORD dwSize,
			IN		LPCSTR szXexName,
			IN		DWORD dwModuleTypeFlags,
			IN		DWORD dwMinimumVersion,
			IN OUT	PHANDLE pHandle
		);

	NTSYSAPI
		EXPORTNUM(259)
		HRESULT
		NTAPI
		ObCreateSymbolicLink(
			IN		PSTRING SymbolicLinkName,
			IN		PSTRING DeviceName
		);

	NTSYSAPI
		EXPORTNUM(260)
		HRESULT
		NTAPI
		ObDeleteSymbolicLink(
			IN		PSTRING SymbolicLinkName
		);

	EXPORTNUM(99)
		VOID KeFlushEntireTb();

	NTSYSAPI
		EXPORTNUM(16)
		NTSTATUS
		NTAPI
		ExGetXConfigSetting(
			IN		WORD dwCategory,
			IN		WORD dwSetting,
			OUT		PVOID pBuffer,
			IN		WORD cbBuffer,
			OUT		PWORD szSetting
		);
}

// flags for xex load image dwModuleTypeFlags
#define XEX_LOADIMG_FLAG_TITLE_PROCESS   0x00000001
#define XEX_LOADIMG_FLAG_TITLE_IMPORTS   0x00000002
#define XEX_LOADIMG_FLAG_DEBUGGER        0x00000004
#define XEX_LOADIMG_FLAG_DLL             0x00000008
#define XEX_LOADIMG_FLAG_PATCH           0x00000010
#define XEX_LOADIMG_FLAG_PATCH_FULL      0x00000020
#define XEX_LOADIMG_FLAG_PATCH_DELTA     0x00000040
#define XEX_LOADIMG_FLAG_BOUND_PATH      0x40000000
#define XEX_LOADIMG_FLAG_SILENT_LOAD     0x80000000
#define XEX_LOADIMG_TYPE_TITLE 			(XEX_LOADIMG_FLAG_TITLE_PROCESS)
#define XEX_LOADIMG_TYPE_TITLE_DLL 		(XEX_LOADIMG_FLAG_TITLE_PROCESS | XEX_LOADIMG_FLAG_DLL)
#define XEX_LOADIMG_TYPE_SYSTEM_APP 	(XEX_LOADIMG_FLAG_DLL)
#define XEX_LOADIMG_TYPE_SYSTEM_DLL 	(XEX_LOADIMG_FLAG_DLL | XEX_LOADIMG_FLAG_TITLE_IMPORTS)

// flags used by ExCreateThread
#define EX_CREATE_FLAG_SUSPENDED		0x00000001 // thread created suspended
#define EX_CREATE_FLAG_SYSTEM			0x00000002 // create a system thread
#define EX_CREATE_FLAG_TLS_STATIC		0x00000008 // allocates more object memory, KPROCESS.SizeOfTlsSlots+KPROCESS.SizeOfTlsStaticData
#define EX_CREATE_FLAG_PRIORITY1		0x00000020 // sets priority class for the thread to 1 via KeSetPriorityClassThread - foreground
#define EX_CREATE_FLAG_PRIORITY0		0x00000040 // sets priority class for the thread to 0 via KeSetPriorityClassThread - background
#define EX_CREATE_FLAG_RETURN_KTHREAD	0x00000080 // puts PKTHREAD into pHandle instead of the thread HANDLE
#define EX_CREATE_FLAG_TITLE_EXEC		0x00000100 // title execution thread
#define EX_CREATE_FLAG_HIDDEN			0x00000400 // hides the thread from debugger thread list
// { more in here in regards to thread scheduler }
#define EX_CREATE_FLAG_CORE0			0x01000000 // threads starts on 1st cpu core
#define EX_CREATE_FLAG_CORE1			0x02000000 // threads starts on 2nd cpu core
#define EX_CREATE_FLAG_CORE2			0x04000000 // threads starts on 3rd cpu core
#define EX_CREATE_FLAG_CORE3			0x08000000 // threads starts on 4th cpu core
#define EX_CREATE_FLAG_CORE4			0x10000000 // threads starts on 5th cpu core
#define EX_CREATE_FLAG_CORE5			0x20000000 // threads starts on 6th cpu core


#define THREAD_PRIORITY_TIME_CRITICAL   THREAD_BASE_PRIORITY_LOWRT

#include "Locale.h"
#include "Utils.h"
#include "HVFuncs.h"
#include "FreebootPatches.h"
#include "Dashlaunch.h"
