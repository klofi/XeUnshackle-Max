//==========================================================================================================================
//
//											- XeUnshackle Max -
//			A simple app designed to apply a full set of freeboot/xebuild kernel & HV patches to a running system
//			after running the Xbox360BadUpdate HV exploit. Sets up & loads a version of launch.xex (Dashlaunch)
//          designed to run from hdd or usb root rather than flash (nand).
//
// Created by: Byrom
// 
// Credits: 
//          grimdoomer - Xbox360BadUpdate exploit.
//          cOz - Dashlaunch, xeBuild patches and much more.
//          Visual Studio / GoobyCorp
//          Diamond
//          InvoxiPlayGames - FreeMyXe, Usbdsec patches, RoL restore and general help.
//          Jeff Hamm - https://www.youtube.com/watch?v=PantVXVEVUg - Chain break video
//          ikari - freeBOOT
//          Xbox360Hub Discord #coding-corner
//          Eaton - Bad Storage
//          Anyone else who has contributed anything to the 360 scene. Apologies if any credits were missed.
// 
// Notes: 
//          This is basically what I came up with during initial testing so could prob be simplified & improved a lot.
//==========================================================================================================================

#include "stdafx.h"

const WCHAR* APP_VERS = L"1.0.0";

// A video dropped next to the .xex (in the BadUpdatePayload folder) is played in place of the built-in one.
// Named after the app like XeUnshackleConfig.txt rather than "bootanim", which in this scene means the
// file in flash that must never be replaced.
#define ExternalVideoPath "GAME:\\XeUnshackleVideo.wmv"

// Get global access to the main D3D device
extern D3DDevice* g_pd3dDevice;
DWORD YellowText = 0xFFFFFF00;
DWORD WhiteText = 0xFFFFFFFF;
DWORD GreyText = 0xFF808080;
DOUBLE dDefaultAutoStartTimer = 2; // 2 seconds
// What the config file holds, kept whole so saving never drops a setting. Assigned in main() before the ui runs
Config_t savedConfig = { -1.0, TRUE, TRUE, 100 };
BOOL bShowKeys = TRUE; // On-screen key visibility. Toggled with A, never saved to the config
BOOL bShouldPlaySuccessVid = FALSE;
WCHAR wTitleHeaderBuf[100];
WCHAR wCPUKeyBuf[150];
WCHAR wDVDKeyBuf[50];
WCHAR wConTypeBuf[50];
WCHAR wBadStorageStatusBuf[21];

// Drawn in place of the real keys while they are hidden. Both keys are always the same
// fixed length (4 x %08X = 32 digits), so the mask is a literal rather than something built at runtime.
#define KEY_HIDDEN_DIGITS L"********************************"
C_ASSERT(_countof(KEY_HIDDEN_DIGITS) == 32 + 1);
const WCHAR* wCPUKeyHidden = L"CPUKey: " KEY_HIDDEN_DIGITS;
const WCHAR* wDVDKeyHidden = L"DVDKey: " KEY_HIDDEN_DIGITS;

//--------------------------------------------------------------------------------------
// Name: class Sample
// Desc: Main class to run this application. Most functionality is inherited
//       from the ATG::Application base class.
//--------------------------------------------------------------------------------------
class XeUnshackle : public ATG::Application
{
    // Pointer to XMV player object.
    IXMedia2XmvPlayer* m_xmvPlayer;
    // Structure for controlling where the movie is played.
    XMEDIA_VIDEO_SCREEN m_videoScreen;

    
    // Tell XMV player about scaling and rotation parameters.
    VOID            InitVideoScreen();

    // XAudio2 object.
    IXAudio2* m_pXAudio2;

    ATG::Timer m_Timer;
    ATG::Font m_Font;
    ATG::Help m_Help;
    BOOL m_bDrawHelp;

    // Countdown timer to app exiting when using Auto-Start
    DOUBLE m_autoStartExitTimer;

public:
    VOID SetAutoStartExitTimer(DOUBLE timerValue)
    {
        if (timerValue >= 0.0)
        {
            m_Timer.GetElapsedTime(); // Prime the timer to reset the value since last call
        }
        m_autoStartExitTimer = timerValue;
    }

private:
    virtual HRESULT Initialize();
    virtual HRESULT Update();
    virtual HRESULT Render();
};


//--------------------------------------------------------------------------------------
// Name: Initialize()
// Desc: This creates all device-dependent display objects.
//--------------------------------------------------------------------------------------
HRESULT XeUnshackle::Initialize()
{
    m_xmvPlayer = 0;

    // Initialize the XAudio2 Engine. The XAudio2 Engine is needed for movie playback.
    UINT32 flags = 0;
#ifdef _DEBUG
    flags |= XAUDIO2_DEBUG_ENGINE;
#endif

    HRESULT hr = XAudio2Create(&m_pXAudio2, flags);
    if (FAILED(hr))
        ATG::FatalError("Error %#X calling XAudio2Create\n", hr);

    IXAudio2MasteringVoice* pMasteringVoice = NULL;
    hr = m_pXAudio2->CreateMasteringVoice(&pMasteringVoice);
    if (FAILED(hr))
        ATG::FatalError("Error %#X calling CreateMasteringVoice\n", hr);

    // SetVolume takes an amplitude multiplier and loudness is logarithmic, so square the fraction for a slider-like taper.
    // This only scales this app's playback and leaves the console's system volume alone.
    const float fVolume = savedConfig.VideoVolume / 100.0f;
    pMasteringVoice->SetVolume(fVolume * fVolume);

    // Create the font
    if (FAILED(m_Font.Create("embed:\\FONT")))
        return ATGAPPERR_MEDIANOTFOUND;

    // Confine text drawing to the title safe area
    m_Font.SetWindow(ATG::GetTitleSafeArea());

    return S_OK;
}


//--------------------------------------------------------------------------------------
// Name: InitVideoScreen()
// Desc: Adjust how the movie is displayed on the screen. Horizontal and vertical
//      scaling and rotation are applied.
//--------------------------------------------------------------------------------------
VOID XeUnshackle::InitVideoScreen()
{
    const int width = m_d3dpp.BackBufferWidth;
    const int height = m_d3dpp.BackBufferHeight;
    const int hWidth = width / 2;
    const int hHeight = height / 2;

    // Parameters to control scaling and rotation of video.
    float m_angle = 0.0;
    float m_xScale = 1.0;
    float m_yScale = 1.0;

    // Scale the output width.
    float left = -hWidth * m_xScale;
    float right = hWidth * m_xScale;
    float top = -hHeight * m_yScale;
    float bottom = hHeight * m_yScale;

    float cosTheta = cos(m_angle);
    float sinTheta = sin(m_angle);

    // Apply the scaling and rotation.
    m_videoScreen.aVertices[0].fX = hWidth + (left * cosTheta - top * sinTheta);
    m_videoScreen.aVertices[0].fY = hHeight + (top * cosTheta + left * sinTheta);
    m_videoScreen.aVertices[0].fZ = 0;

    m_videoScreen.aVertices[1].fX = hWidth + (right * cosTheta - top * sinTheta);
    m_videoScreen.aVertices[1].fY = hHeight + (top * cosTheta + right * sinTheta);
    m_videoScreen.aVertices[1].fZ = 0;

    m_videoScreen.aVertices[2].fX = hWidth + (left * cosTheta - bottom * sinTheta);
    m_videoScreen.aVertices[2].fY = hHeight + (bottom * cosTheta + left * sinTheta);
    m_videoScreen.aVertices[2].fZ = 0;

    m_videoScreen.aVertices[3].fX = hWidth + (right * cosTheta - bottom * sinTheta);
    m_videoScreen.aVertices[3].fY = hHeight + (bottom * cosTheta + right * sinTheta);
    m_videoScreen.aVertices[3].fZ = 0;

    // Always leave the UV coordinates at the default values.
    m_videoScreen.aVertices[0].fTu = 0;
    m_videoScreen.aVertices[0].fTv = 0;
    m_videoScreen.aVertices[1].fTu = 1;
    m_videoScreen.aVertices[1].fTv = 0;
    m_videoScreen.aVertices[2].fTu = 0;
    m_videoScreen.aVertices[2].fTv = 1;
    m_videoScreen.aVertices[3].fTu = 1;
    m_videoScreen.aVertices[3].fTv = 1;

    // Tell the XMV player to use the new settings.
    // This locks the vertex buffer so it may cause stalls if called every frame.
    m_xmvPlayer->SetVideoScreen(&m_videoScreen);
}


//--------------------------------------------------------------------------------------
// Name: Update()
// Desc: Called once per frame, the call is the entry point for animating the scene.
//       The movie is played from here.
//--------------------------------------------------------------------------------------
HRESULT XeUnshackle::Update()
{
    // Get the current gamepad state
    ATG::GAMEPAD* pGamepad = ATG::Input::GetMergedInput();

    // If the Auto-Start timer is active, count it down (optionally letting the boot video play first)
    if(m_autoStartExitTimer >= 0.0)
    {
        if (!DisableButtons && (pGamepad->wPressedButtons & XINPUT_GAMEPAD_B))
        {
            // Cancel Auto-Start, stopping the boot video too if it's currently playing
            if (m_xmvPlayer)
            {
                m_xmvPlayer->Stop(XMEDIA_STOP_IMMEDIATE);
            }
            SetAutoStartExitTimer(-1.0);
            return S_OK;
        }

        // Count down once the boot video is done playing (or was never requested). While it's
        // still playing or pending, fall through to the normal video playback logic below instead.
        if (!m_xmvPlayer && !bShouldPlaySuccessVid)
        {
            m_autoStartExitTimer -= m_Timer.GetElapsedTime();

            // When the timer runs out, launch the default app
            if (m_autoStartExitTimer <= 0.0)
            {
                XLaunchNewImage(XLAUNCH_KEYWORD_DEFAULT_APP, 0);
            }

            // Return here so video playback and button presses are not processed when using Auto-Start
            return S_OK;
        }

        // Keep the countdown timer primed while the boot video plays, so the time spent
        // playing the video isn't subtracted from the countdown once it actually starts.
        m_Timer.GetElapsedTime();
    }

    if (m_xmvPlayer)
    {
        // 'B' means cancel the movie.
        if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_B)
        {
            m_xmvPlayer->Stop(XMEDIA_STOP_IMMEDIATE);
        }
    }
    else
    {
        // Play the movie if required
        if (bShouldPlaySuccessVid)
        {
            XMEDIA_XMV_CREATE_PARAMETERS XmvParams;

            ZeroMemory(&XmvParams, sizeof(XmvParams));

            // Use the default audio and video streams.
            // If using a wmv file with multiple audio or video streams
            // (such as different audio streams for different languages)
            // the dwAudioStreamId & dwVideoStreamId parameters can be used 
            // to select which audio (or video) stream will be played back

            XmvParams.dwAudioStreamId = XMEDIA_STREAM_ID_USE_DEFAULT;
            XmvParams.dwVideoStreamId = XMEDIA_STREAM_ID_USE_DEFAULT;

            bShouldPlaySuccessVid = FALSE; // Reset so we don't play again

            // Play the user's own video when they've put one next to the .xex. It's streamed straight from
            // the file so a large video costs no extra memory, unlike the embedded one below.
            if (FileExists(ExternalVideoPath))
            {
                cprintf("[XeUnshackle] Found %s, playing it in place of the built-in video", ExternalVideoPath);

                XmvParams.createType = XMEDIA_CREATE_FROM_FILE;
                XmvParams.createFromFile.szFileName = ExternalVideoPath;
                // The remaining createFromFile fields are left zeroed to use the default file IO behaviour.

                HRESULT hr = XMedia2CreateXmvPlayer(m_pd3dDevice, m_pXAudio2, &XmvParams, &m_xmvPlayer);
                if (FAILED(hr))
                {
                    // The file is there but unplayable (an mp4 renamed to .wmv, for example), so fall back to
                    // the built-in video rather than dropping the user straight to the info screen. Notify
                    // them too, otherwise the built-in video playing looks like their file was ignored.
                    m_xmvPlayer = 0; // A failed create must not leave a stale pointer behind
                    cprintf("[XeUnshackle] Error %#X playing %s. Falling back to the built-in video...", hr, ExternalVideoPath);
                    ShowNotify(currentLocalisation->CustomVideo_Fail);
                }
            }

            // Create from embedded resource unless the user's own video is already playing
            if (!m_xmvPlayer)
            {
                VOID* pSectionData;
                DWORD dwSectionSize;
                HMODULE hModule = GetModuleHandle(NULL);
                if (XGetModuleSection(hModule, "VID", &pSectionData, &dwSectionSize))
                {
                    XmvParams.createType = XMEDIA_CREATE_FROM_MEMORY;
                    XmvParams.createFromMemory.pvBuffer = pSectionData;
                    XmvParams.createFromMemory.dwBufferSize = dwSectionSize;

                    if (FAILED(XMedia2CreateXmvPlayer(m_pd3dDevice, m_pXAudio2, &XmvParams, &m_xmvPlayer)))
                    {
                        m_xmvPlayer = 0;
                    }
                }
            }

            if (m_xmvPlayer)
            {
                InitVideoScreen();
            }
        }

        // Only process these while Auto-Start isn't active (Auto-Start's B-cancel is handled above),
        // and not on the frame a video just started playing.
        if (!m_xmvPlayer && !DisableButtons && m_autoStartExitTimer < 0.0)
        {
            if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_BACK)
            {
                XLaunchNewImage(XLAUNCH_KEYWORD_DEFAULT_APP, 0);
            }
            else if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_START)
            {
                if (savedConfig.AutoStartDelay >= 0.0)
                {
                    SetAutoStartExitTimer(savedConfig.AutoStartDelay);
                }
                else
                {
                    // Only Auto-Start is being set up here, so every other setting is written back
                    // with the value it was loaded with (a hand-set ShowKeys=0 survives, for example)
                    savedConfig.AutoStartDelay = dDefaultAutoStartTimer;
                    SaveConfig(savedConfig);
                    SetAutoStartExitTimer(dDefaultAutoStartTimer);
                }
            }
            else if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_X)
            {
                SaveConsoleDataToFile();
            }
            else if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_Y)
            {
                Dump1blRomToFile();
            }
            else if (pGamepad->wPressedButtons & XINPUT_GAMEPAD_A)
            {
                // Show/hide the keys for this session only, never written to the config
                bShowKeys = !bShowKeys;
            }
        }
    }


    return S_OK;
}


//--------------------------------------------------------------------------------------
// Name: Render()
// Desc: Sets up render states, clears the viewport, and renders the scene.
//--------------------------------------------------------------------------------------
HRESULT XeUnshackle::Render()
{
    // Draw a gradient filled background
    //ATG::RenderBackground(0xff0000ff, 0xff000000);

    // If we are currently playing a movie.
    if (m_xmvPlayer)
    {
        // If RenderNextFrame does not return S_OK then the frame was not
        // rendered (perhaps because it was cancelled) so a regular frame
        // buffer should be rendered before calling present.
        HRESULT hr = m_xmvPlayer->RenderNextFrame(0, NULL);

        // Reset our cached view of what pixel and vertex shaders are set, because
        // it is no longer accurate, since XMV will have set their own shaders.
        // This avoids problems when the shader cache thinks it knows what shader
        // is set and it is wrong.
        m_pd3dDevice->SetVertexShader(0);
        m_pd3dDevice->SetPixelShader(0);
        m_pd3dDevice->SetVertexDeclaration(0);

        if (FAILED(hr) || hr == (HRESULT)XMEDIA_W_EOF)
        {
            // Release the movie object
            m_xmvPlayer->Release();
            m_xmvPlayer = 0;
            // Movie playback changes various D3D states, so you should reset the
            // states that you need after movie playback is finished.
            m_pd3dDevice->SetRenderState(D3DRS_VIEWPORTENABLE, TRUE);
        }

    }

    else
    {
        ATG::RenderBackground(0xFF000032, 0xFF000032);
        m_Font.Begin();
        m_Font.SetScaleFactors(1.5f, 1.5f);
        m_Font.DrawText(0, 0, YellowText, wTitleHeaderBuf);

        // Pre-Release Build Identifier
        //m_Font.DrawText(840, 0, WhiteText, L"[TEST BUILD]");
        //

        m_Font.SetScaleFactors(1.0f, 1.0f);

        // General info
        m_Font.DrawText(0, 70, YellowText, currentLocalisation->MainInfo);

		// Bad Storage info
		m_Font.DrawText(0, 260, YellowText, wBadStorageStatusBuf);

        // Dashlaunch Info
        m_Font.DrawText(0, 290, YellowText, wDLStatusBuf);
        if (bDLisLoaded)
        {
            m_Font.DrawText(0, 320, YellowText, currentLocalisation->MainScrDL);
        }

        // Console Info
        m_Font.DrawText(0, 460, YellowText, wConTypeBuf);
        m_Font.DrawText(0, 490, YellowText, bShowKeys ? wCPUKeyBuf : wCPUKeyHidden);
        m_Font.DrawText(0, 520, YellowText, bShowKeys ? wDVDKeyBuf : wDVDKeyHidden);

        m_Font.DrawText(0, 570, YellowText, L"Max: https://github.com/Klofi/XeUnshackle-Max");
        m_Font.DrawText(0, 600, YellowText, L"Original: https://github.com/Byrom90/XeUnshackle");

        // If the timer is not active, draw the normal button prompts, otherwise draw the countdown text
        if (m_autoStartExitTimer < 0.0)
        {
            // User input with buttons - Make these white so they display correctly and stand out to the user.
            // The actions on this screen sit in the top group, leaving/configuring the app in the bottom one.
            m_Font.DrawText(740, 460, WhiteText, currentLocalisation->MainScrBtnSaveInfo);// X button icon with text
            m_Font.DrawText(740, 490, WhiteText, currentLocalisation->MainScrBtnDump1BL);// Y button icon with text
            m_Font.DrawText(740, 520, WhiteText, bShowKeys ? currentLocalisation->MainScrBtnHideKeys : currentLocalisation->MainScrBtnShowKeys);// A button icon with text

            m_Font.DrawText(740, 560, WhiteText, currentLocalisation->MainScrBtnExit);// Back button icon with text
            m_Font.DrawText(740, 600, WhiteText, currentLocalisation->MainScrBtnAutoStartSet);// Start button icon with text
        }
        else
        {
            // Format the string to include countdown value
            WCHAR szCountdown[150];
            swprintf_s(szCountdown, currentLocalisation->MainScrAutoStartRunning, m_autoStartExitTimer);

            // Draw the countdown text where the button prompts would normally be
            m_Font.DrawText(740, 570, GreyText, szCountdown);
            m_Font.DrawText(740, 600, WhiteText, currentLocalisation->MainScrBtnAutoStartCancel);// B button icon with text
        }

        m_Font.End();
    }

    
    

    // Present the scene
    m_pd3dDevice->Present(NULL, NULL, NULL, NULL);

    return S_OK;
}

typedef BOOLEAN (*pfnBadStorageExecute)(PBOOLEAN RetailFormatted);

//--------------------------------------------------------------------------------------
// Name: main()
// Desc: Entry point to the program
//--------------------------------------------------------------------------------------
VOID __cdecl main()
{
    SetLocale(); // Set the correct locale so text will be displayed in the correct language

    // Part 1 - We apply the HV patches here (if required)
    if (!Hvx::CheckPPExpHVAccess()) // If we have pp access then assume we have done this previously
    {
        if (!Hvx::DisableExpChecks()) // Stage 1 - Apply HV patches to disable checks on expansions. If this fails do not proceed
        {
            cprintf("[XeUnshackle] Stage 1 failed!");
            ShowErrorAndExit(1);
        }
        cprintf("[XeUnshackle] Stage 1 success!");
        if (!Hvx::SetupPPExpHVAccess()) // Stage 2 - Install the peek poke expansion. If this fails do not proceed
        {
            cprintf("[XeUnshackle] Stage 2 failed!");
            ShowErrorAndExit(2);
        }
        cprintf("[XeUnshackle] Stage 2 success!");
        if (!Hvx::CheckPPExpHVAccess()) // Stage 3 - Check if we now have HV access via Peek Poke expansion. If this fails do not proceed
        {
            cprintf("[XeUnshackle] Stage 3 failed!");
            ShowErrorAndExit(3);
        }
        cprintf("[XeUnshackle] Stage 3 success!");
        if (!ApplyFreebootHVPatches())
        {
            cprintf("[XeUnshackle] Stage 4 failed!");
            ShowErrorAndExit(4);
        }
        cprintf("[XeUnshackle] Stage 4 success!");

        //cprintf("[XeUnshackle] Relaunching before proceeding with Stage 5!"); // NO LONGER REQUIRED
        //RelaunchApp();

        // No more relaunching
        cprintf("[XeUnshackle] Calling KeFlushEntireTb");
        KeFlushEntireTb(); // This is called in XexpTitleTerminateNotification. Maybe this is why relaunching works???

    }
    // Part 2 - We end up here if part 1 succeeded in gaining HV access via expansions
    cprintf("[XeUnshackle] Checking kernel patch state");
    if (*(DWORD*)0x80108E70 != 0x48003134) // This is the last freeboot kernel patch applied. This determines whether we have applied them yet
    {
        if (!ApplyFreebootKernPatches())
        {
            cprintf("[XeUnshackle] Stage 5 failed!");
            ShowErrorAndExit(5);
        }
        ApplyAdditionalPatches(); // Other patches for general fixes

        RestoreRoL(); // Restore the default RoL state

        cprintf("[XeUnshackle] Calling KeFlushEntireTb");
        KeFlushEntireTb();

        cprintf("[XeUnshackle] Stage 5 success!");
    }
    // Part 3 - We should only ever begin here for any subsequent launches of the app

	//Execute Bad Storage. Must happen before loading Dashlaunch. This gives people the ability to use internal drives up to 2 TB.
	//If something unusual happens, Bad Storage will pop an XNotify with more details and return FALSE.
	//In cases where it is run with a retail-formatted drive, FALSE is returned, no XNotify is shown, and IsRetailFormatted is set to TRUE. FATXplorer 3.0 beta 36 has the Bad Storage formatting feature.
	//TRUE is returned on successful execution. Bad Storage also checks for repeated executions internally, so there is no problem executing multiple times.
	HMODULE bstorDLL = LoadLibrary("GAME:\\BadStorage.xex.dll");
	ZeroMemory(wBadStorageStatusBuf, sizeof(wBadStorageStatusBuf));
	if (bstorDLL != NULL)
	{
		BOOLEAN bstorIsRetailFormatted;
		if (((pfnBadStorageExecute)GetProcAddress(bstorDLL, (LPCSTR)1))(&bstorIsRetailFormatted))
		{
			swprintf_s(wBadStorageStatusBuf, L"Bad Storage: Applied");
			cprintf("[XeUnshackle] Bad Storage executed successfully");
		}
		else
		{
			swprintf_s(wBadStorageStatusBuf, L"Bad Storage: %s", bstorIsRetailFormatted ? L"Skipped" : L"Failed");
			cprintf("[XeUnshackle] Bad Storage executed unsuccessfully");
		}
		FreeLibrary(bstorDLL);
	}
	else
	{
		swprintf_s(wBadStorageStatusBuf, L"Bad Storage: Missing");
		cprintf("[XeUnshackle] BadStorage.xex.dll not found");
	}

    // If Dashlaunch loaded successfully we can revert the patches done by BadUpdate. 
    // Needs to be like this due to Dashlaunch fixing Retail signed xex files that have been patched.
    // BadUpdate patches also allow this but prevent the Freeboot patches from functioning correctly
    // IMPORTANT NOTE: Dashlaunch doesn't appear to load the plugins until you exit to dash aka the next executable load.
    // 0 = FAILED
    // 1 = SUCCESS
    // 2 = Already loaded
    
    if (SysLoadDashlaunch() == 1) // We always call this here since it also sets up the wchar buffer to display in the app for Dashlaunch load status
    {

        RevertBadExploitPatches(); // Restore changes made by the exploit
    }

    cprintf("[XeUnshackle] All patches have been applied! Proceeding to init the ui...");

    // Grab some stuff for display in the ui
    ZeroMemory(wTitleHeaderBuf, sizeof(wTitleHeaderBuf));
    swprintf_s(wTitleHeaderBuf, L"%ls XeUnshackle Max v%ls %ls", GLYPH_RIGHT_TICK, APP_VERS, GLYPH_LEFT_TICK);
    // Motherboard type
    ZeroMemory(wConTypeBuf, sizeof(wConTypeBuf));
    swprintf_s(wConTypeBuf, L"Console type: %S", GetMoboByHWFlags().c_str());
    // cpu key
    QWORD fuse3 = Hvx::HvGetFuseline(3);
    QWORD fuse5 = Hvx::HvGetFuseline(5);
    ZeroMemory(wCPUKeyBuf, sizeof(wCPUKeyBuf));
    swprintf_s(wCPUKeyBuf, L"CPUKey: %08X%08X%08X%08X", fuse3 >> 32, fuse3 & 0xffffffff, fuse5 >> 32, fuse5 & 0xffffffff);
    // dvd key
    BYTE DVDKeyBytes[16];
    QWORD kvAddress = Hvx::HvPeekQWORD(0x00000002000163C0);
    Hvx::HvPeekBytes(kvAddress + 0x100, DVDKeyBytes, 16);
    ZeroMemory(wDVDKeyBuf, sizeof(wDVDKeyBuf));
    swprintf_s(wDVDKeyBuf, L"DVDKey: %08X%08X%08X%08X", *(DWORD*)(DVDKeyBytes), *(DWORD*)(DVDKeyBytes + 4), *(DWORD*)(DVDKeyBytes + 8), *(DWORD*)(DVDKeyBytes + 12));

    BackupOrigMAC(); // This will cause a notify to pop before the video has played completely but only if it hasn't been dumped previously

    // Run the ui portion of the app with video etc...
    XeUnshackle atgApp;

    // For movie playback we want to synchronize to the monitor.
    atgApp.m_d3dpp.PresentationInterval = D3DPRESENT_INTERVAL_ONE;
    ATG::GetVideoSettings(&atgApp.m_d3dpp.BackBufferWidth, &atgApp.m_d3dpp.BackBufferHeight);

    // Load the config; AutoStartDelay will be negative when Auto-Start isn't set up, so it doesn't trigger countdown
    savedConfig = LoadConfig();
    // ShowKeys only seeds the initial visibility, toggling with A afterward never touches the config
    bShowKeys = savedConfig.ShowKeys;
    bShouldPlaySuccessVid = savedConfig.PlayVideo;
    atgApp.SetAutoStartExitTimer(savedConfig.AutoStartDelay);

    atgApp.Run();
}
