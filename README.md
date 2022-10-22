# pwsh-kamyroll
A implementation of the Kamyroll API in powershell

> **Warning**
> 
> This was put together in about 15 hours, so might be buggy at some points.
> 
> I provide no warranty or gurantee of any kind.

## How to use:
1. Download `cli.ps1` and `kamyrollAPI.ps1`
2. Put `kamyrollAPI.ps1` in the folder you want the video files to go
3. Open `cli.ps1` in notepad or your code editor of choice
4. Change $defaultFolder to the folder `kamyrollAPI.ps1` is in

![image](https://user-images.githubusercontent.com/39769465/197365873-1f73fa6f-52d7-4aa8-b6ed-1609a17c12b1.png)

5. Run `cli.ps1` from anywhere you want.

6. (Optional) Create `C:\Users\<yourName>\.config\powershell\user_profile.ps1` and set it's contents to
```Powershell
Function startKamy {
. "<path to cli.ps1>"
}
Set-Alias Kamyroll startKamy
```
That way each time you type "Kamyroll" into powershell it will start the cli

---

The CLI was made with menus from [PSMenu](https://github.com/Sebazzz/PSMenu)
