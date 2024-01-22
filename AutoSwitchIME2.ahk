#Requires AutoHotkey v2.0
#NoTrayIcon
SetWorkingDir(A_ScriptDir)
INI := "WMAutoSwitch.ini" ;配置文件名
Persistent			;让脚本持久运行(关闭或ExitApp)

; 管理员启动
Label_AdminLaunch: 
    full_command_line := DllCall("GetCommandLine", "str")
    if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
    {
        try
        {
            if A_IsCompiled
                Run '*RunAs "' A_ScriptFullPath '" /restart'
            else
                Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        }
        ExitApp
    }

;自动切换功能
INI_EN := IniRead(INI, "英文输入法窗口")
INI_CNEN := IniRead(INI, "英文窗口")
Auto_Switch := 1
CN_Code:=0x804,EN_Code:=0x409 ; KBL代码
global AutoSwitchFrequency := 0 ; 自动切换次数统计
;自动切换enum
AutoSwitchMap := Map() 
AutoSwitchMap["en"] := 2
AutoSwitchMap["cnen"] := 1

groupNameObj := Object()

; 监听窗口切换输入法
DllCall("ChangeWindowMessageFilter", "UInt", 0x4A, "UInt" , 1) ; 接受非管理员权限RA消息
If (Auto_Switch=1){ ; 监听窗口消息
    getINISwitchWindows(INI_EN,"en_ahk_group") ; 英文输入法窗口
    getINISwitchWindows(INI_CNEN,"cnen_ahk_group")  ; 中文输入法英文文模式窗口
    DllCall("RegisterShellHookWindow", "UInt", A_ScriptHwnd)
    shell_msg_num := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    shell_run := shellMessage.Bind()
    OnMessage(shell_msg_num, shell_run)
}
Receive := Receive_WM_COPYDATA.Bind()
OnMessage(0x004A, Receive)

SetTimer_ResetshellMessageFlag(){ ;窗口切换标志
    ; 定时重置未在接收切换消息
    shellMessageFlag := 0
} 
; 根据激活窗口切换输入法
Shell_KBLSwitch(){ 
    Critical("On")
    If WinActive("ahk_group en_ahk_group"){ ;窗口组切换英文输入法
        setKBLlLayout(AutoSwitchMap["en"],1)
    }
    If WinActive("ahk_group cnen_ahk_group"){ ;切换英文(中文)输入法
        setKBLlLayout(AutoSwitchMap["cnen"],1)
    }
    Critical("off")
}
; 接受系统窗口回调消息切换输入法, 第一次是实时，第二次是保障
shellMessage(wParam, lParam,*) {
    If ( wParam=1 || wParam=32772 || wParam=5 || wParam=4) {
        shellMessageFlag := 1
        timer := SetTimer_ResetshellMessageFlag.Bind()
        SetTimer timer,-500
        Shell_KBLSwitch()
    }
}

; 设置输入法键盘布局
setKBLlLayout(KBL:=0,Source:=0) {
    global AutoSwitchFrequency := Source + AutoSwitchFrequency
    gl_Active_IMEwin_id := getIMEwinid()
    LastKBLCode := getIMEKBL(gl_Active_IMEwin_id)
    If (KBL=AutoSwitchMap["en"]){ ; 切换英文输入法
        If (LastKBLCode!=EN_Code)
            PostMessage 0x50, , EN_Code, ,gl_Active_IMEwin_id
    }
    If (KBL=AutoSwitchMap["cnen"]){ ; 切换英文(中文)输入法
        If (LastKBLCode!=CN_Code)
            SendMessage 0x50, , CN_Code, , gl_Active_IMEwin_id
            setIME(0,gl_Active_IMEwin_id)
        If (LastKBLCode=CN_Code) {
            setIME(0,gl_Active_IMEwin_id)
        }
    }
}
; 设置输入法状态-获取状态-末位设置
setIME(setSts, win_id:="") {
    try {
        MsgReply := SendMessage(0x283, 0x001, 0, , win_id)
        CONVERSIONMODE := 2046&MsgReply
        CONVERSIONMODE += setSts
        Sleep(800) ; 我也不知道什么原理，估计是IME内部要自动切换到上次的状态，所以你必须再次更新覆盖状态，总之改变就是好事
        MsgReply := SendMessage(0x283, 0x002, CONVERSIONMODE, , win_id)
        MsgReply := SendMessage(0x283, 0x006, setSts, , win_id)
        return MsgReply
    } catch TargetError as e {
        return 0 ;未知原因导致检测不到窗口，非常奇怪的bug
    }
}
; 获取激活窗口IME线程id
getIMEwinid() { 
    If WinActive("ahk_group focus_control_ahk_group"){
        FocusedHwnd := ControlGetFocus("A")
        CClassNN := ControlGetClassNN(FocusedHwnd)
        If (CClassNN = "")
            win_id := WinGetID("A")
        Else
            win_id := ControlGetHwnd(CClassNN)
    }Else
        win_id := WinGetID("A")
    ImmGetDefaultIMEWnd := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "imm32", "Ptr"), "AStr", "ImmGetDefaultIMEWnd", "Ptr")
    IMEwin_id := DllCall(ImmGetDefaultIMEWnd, "Uint", win_id, "Uint")
    Return IMEwin_id
}
; 获取激活窗口键盘布局
getIMEKBL(win_id:="") { 
    thread_id := DllCall("GetWindowThreadProcessId", "UInt", win_id, "UInt", 0)
    IME_State := DllCall("GetKeyboardLayout", "UInt", thread_id)
    Switch IME_State
    {
        Case 134481924:Return 2052
        Case 67699721:Return 1033
        Default:Return IME_State
    }
}


;获取Win32 API消息
Receive_WM_COPYDATA(&wParam,&lParam) {
    StringAddress := NumGet(lParam, 2*A_PtrSize, "Ptr")  ; 获取 CopyDataStruct 的 lpData 成员.
    CopyOfData := StrGet(StringAddress)  ; 从结构中复制字符串.
    return true  ; 返回 1(true) 是回复此消息的传统方式.
}

; 此函数发送指定的字符串到指定的窗口然后返回收到的回复.
; 如果目标窗口处理了消息则回复为 1, 而消息被忽略了则为 0.
Send_WM_COPYDATA(StringToSend, TargetScriptTitle)
{
    CopyDataStruct := Buffer(3*A_PtrSize)  ; 分配结构的内存区域.
    ; 首先设置结构的 cbData 成员为字符串的大小, 包括它的零终止符:
    SizeInBytes := (StrLen(StringToSend) + 1) * 2
    NumPut( "Ptr", SizeInBytes  ; 操作系统要求这个需要完成.
          , "Ptr", StrPtr(StringToSend)  ; 设置 lpData 为到字符串自身的指针.
          , CopyDataStruct, A_PtrSize)
    Prev_DetectHiddenWindows := A_DetectHiddenWindows
    Prev_TitleMatchMode := A_TitleMatchMode
    DetectHiddenWindows True
    SetTitleMatchMode 2
    TimeOutTime := 4000  ; 可选的. 等待 receiver.ahk 响应的毫秒数. 默认是 5000
    ; 必须使用发送 SendMessage 而不是投递 PostMessage.
    RetValue := SendMessage(0x4a, 0, CopyDataStruct,, TargetScriptTitle,,,, TimeOutTime) ; 0x4a 是 WM_COPYDATA.
    DetectHiddenWindows Prev_DetectHiddenWindows  ; 恢复调用者原来的设置.
    SetTitleMatchMode Prev_TitleMatchMode         ; 同样.
    return RetValue  ; 返回 SendMessage 的回复给我们的调用者.
}

;INI解析
getINISwitchWindows(INIVar:="",groupName:="",Delimiters:="`n") { ; 从配置文件读取切换窗口
    Loop parse, INIVar, Delimiters, "`r"
    {
        MyVar := StrSplit(Trim(A_LoopField), "=")
        MyVar_Key := MyVar[1]
        MyVar_Val := MyVar[2]
        If (MyVar_Key="")
            continue
        If (MyVar_Val="")
            MyVar_Val := MyVar_Key
        prefix := SubStr(MyVar_Val, 1, 4)
        If (MyVar_Val="AllGlobalWin")
            GroupAdd groupName
        Else If (groupNameObj.HasOwnProp(MyVar_Val))
            GroupAdd groupName, "ahk_group" A_Space MyVar_Val
        Else If (prefix="uwp "){
            uwp_app := SubStr(MyVar_Val, 5)
            GroupAdd groupName, "ahk_exe ApplicationFrameHost.exe", uwp_app
            GroupAdd groupName, uwp_app
        }Else If (!InStr(MyVar_Val, A_Space) && SubStr(MyVar_Val, -3)=".exe")
            GroupAdd groupName, "ahk_exe" MyVar_Val
        Else
            GroupAdd groupName, MyVar_Val
    }
}

