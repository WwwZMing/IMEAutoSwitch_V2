# 输入法自动切换
修改自KBLAutoSwitch的AHK自动切换输入法脚本。因为原作者Github代码不更新了（本体仍在更新）所以用V2版本重写了一部分代码并删掉了自己并不需要的GUI和大部分实用功能。
功能演示参考原作者的自动切换。

[原仓库链接](https://github.com/flyinclouds/KBLAutoSwitch)

配置文件如下：
```ini
[英文窗口]
文件资源管理器=ahk_class CabinetWClass ahk_exe explorer.exe
vscode=ahk_exe Code.exe
[英文输入法窗口]
WindowsTerminal=ahk_exe WindowsTerminal.exe
yuzu=ahk_exe yuzu.exe
explorer=ahk_class Shell_TrayWnd ahk_exe explorer.exe
```
> PS：可以用Windows Spy获取对应窗口的Class和id,我觉得原来的检测窗口功能并不实用，不如官方自带的好。由于未知原因，win11上失去焦点的app的中文输入法英文切换状态失效了，这个bug目前找不到原因先不修复了。
> 
> **Warning** ：没有做配置文件不存在时的异常处理，所以使用的时候请带上配置文件使用🤣