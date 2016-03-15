---
layout: post
title: Trying to use FAKE (F#) via WinRM with PowerShell
---

This is an overview of the method of combining F# statically typed scripts
with [Windows Remote Manager](https://msdn.microsoft.com/en-us/library/windows/desktop/aa384426.aspx)
remote invokations with a PowerShell. Its based on the following articles:

- https://blogs.msdn.microsoft.com/fsharpteam/2012/10/03/rethinking-findstr-with-f-and-powershell/
- http://tahirhassan.blogspot.ru/2014/06/embedding-f-in-powershell-hacky-way.html
- http://www.old.dougfinke.com/blog/index.php/2007/07/27/embedding-f-in-powershell/
- http://tahirhassan.blogspot.ru/2014/06/embedding-f-in-powershell.html
- http://fsharp.github.io/FSharp.Compiler.Service/
- http://stackoverflow.com/questions/17111622/f-environment-integration-for-scripting
- http://get-powershell.com/post/2008/12/30/Inline-F-in-PowerShell.aspx
- http://stackoverflow.com/questions/30171272/using-f-script-replace-powershell-in-production-environment
- https://github.com/fsprojects/FSharp.Management
- https://sergeytihon.wordpress.com/2013/08/04/powershell-type-provider/
- http://fsprojects.github.io/FSharp.Management/PowerShellProvider.html
- https://www.simple-talk.com/sysadmin/powershell/practical-powershell-unit-testing-getting-started/
- https://github.com/pester/Pester
- https://github.com/fsharp/FAKE
- https://github.com/joeyh/propellor

Run F# scripts inside PowerShell WinRM
======================================

.NET 4.x
--------

Make sure all your hosts have .NET 4.x installed.

Test your PowerShell CLR environment
------------------------------------

```powershell
$PSVersionTable
```

If its not 4.0, there there are two ways to tell PowerShell
version 2.0 to utilize .NET Framework 4.

You’ll want to create powershell.exe.config and
powershell_ise.exe.config and place them in your $pshome directory.

Here is what you want in both of those .config files:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <startup>
      <supportedRuntime version="v4.0.30319" />
      <supportedRuntime version="v2.0.50727" />
    </startup>
</configuration>
```

Here is the location of $pshome by default:

* 32-bit machines: C:\Windows\System32\WindowsPowershell\v1.0
* 64-bit machines
    * 32-bit version: C:\Windows\SysWOW64\WindowsPowershell\v1.0
    * 64-vit version:  C:\Windows\System32\WindowsPowershell\v1.0

or google for `PowerShell .NET 4.0`.

i.e. http://www.adminarsenal.com/admin-arsenal-blog/powershell-running-net-4-with-powershell-v2/

Test your WinRM environment
---------------------------

```powershell
Invoke-Command -ComputerName SECOND -ScriptBlock { Write-Output $env:COMPUTERNAME }
```

Provide `Microsoft Build Tools 2015`
------------------------------------

Microsoft Build Tools 2015 is required for CodeDom to work to mitigate
`Microsoft.Build.Utilities.Core, Version=14.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a`
error.

Install Microsoft Build Tools 2015 from https://go.microsoft.com/fwlink/?LinkId=615458,
it can be installed quietly using: /Quiet /Full.

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    $webclient = New-Object Net.WebClient
    $url = 'https://go.microsoft.com/fwlink/?LinkId=615458'
    $webclient.DownloadFile($url, "$pwd\BuildTools_Full.exe")
    .\BuildTools_Full.exe /Quiet /Full
}

```

This quiet mode didn't work for me as much I've tried.

Provide `FSharp` environment
----------------------------

NuGet `FSharp.Compiler.*` is broken due compatibility with `CodeDom 0.9.4`
and other dependencies of fsi and fsc that would be resolved.

- `FSharp.Compiler.CodeDom 0.9.4` requires `FSharp.Core 4.3.1.0`,
- $env:PATH to fsi/fsc,
- fsc would not work because of other unmet dependencies from some redists.

So, install `FSharp` this [way](http://fsharp.org/use/windows/):

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    $webclient = New-Object Net.WebClient
    $url = 'http://download.microsoft.com/download/9/1/2/9122D406-F1E3-4880-A66D-D6C65E8B1545/FSharp_Bundle.exe'
    $webclient.DownloadFile($url, "$pwd\FSharp_Bundle.exe")
    .\FSharp_Bundle.exe /install /quiet
}

```

This will take some time.

Provide `CodeDom`
-----------------

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    # Cache
    $tools = 'C:\Tools'

    if (-not (Test-Path -Path $tools)) {
        New-Item -Path $tools -ItemType 'directory'
    }

    Set-Location $tools

    # Libs
    @('FSharp.Compiler.CodeDom') | ? {
        -not (Get-ChildItem -Path (Join-Path -Path $tools -ChildPath "$_*"))
    } | % {
        nuget install $_
    }

    # Include
    Add-Type -Path 'C:\Program Files\Reference Assemblies\Microsoft\FSharp\.NETFramework\v4.0\4.3.1.0\FSharp.Core.dll'
    Get-ChildItem -Path C:\Tools\FSharp.Compiler.CodeDom.*\lib\net40\FSharp.Compiler.CodeDom.dll | % { Add-Type -Path $_.FullName }

    # Example of calling -TypeDefinition
    $fibCode = '
        module Fibonacci
        let fibs =
            (1,1) |> Seq.unfold
                (fun (n0,n1) ->
                    Some(n0, (n1, n0 + n1)))
        let get n =
            Seq.item n fibs
    '

    # Compile
    $FSharpCodeProvider = New-Object FSharp.Compiler.CodeDom.FSharpCodeProvider
    Add-Type -TypeDefinition $fibCode -CodeDomProvider $FSharpCodeProvider

    # Test
    [Fibonacci]::get(5)
}

```

Call `fake` somehow from F#
---------------------------

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    # Cache
    $tools = 'C:\Tools'

    if (-not (Test-Path -Path $tools)) {
        New-Item -Path $tools -ItemType 'directory'
    }

    Set-Location $tools

    # Libs
    @('FSharp.Compiler.CodeDom', 'FAKE') | ? {
        -not (Get-ChildItem -Path (Join-Path -Path $tools -ChildPath "$_*"))
    } | % {
        nuget install $_
    }

    # Include
    Add-Type -Path 'C:\Program Files (x86)\Reference Assemblies\Microsoft\FSharp\.NETFramework\v4.0\4.3.1.0\FSharp.Core.dll'
    Get-ChildItem -Path C:\Tools\FSharp.Compiler.CodeDom.*\lib\net40\FSharp.Compiler.CodeDom.dll | % { Add-Type -Path $_.FullName  }

    Get-ChildItem -Path C:\Tools\Fake.*\tools\FakeLib.dll | % {
        $FakeLib = $_.FullName
        Add-Type -Path $_.FullName
    }

    Get-ChildItem -Path C:\Tools\Fake.*\tools | % {
        $FakePath = $_.FullName
        $env:Path = "$env:Path;$($_.FullName)"
    }

    # Script
    $code = `
'
module FakeTest

open Fake

Target "Test" (fun _ ->
    trace "Testing stuff..."
)

Target "Deploy" (fun _ ->
    trace "Heavy deploy action"
)

Run "Deploy"
'

    # Compile
    $FSharpCodeProvider = New-Object FSharp.Compiler.CodeDom.FSharpCodeProvider
    Add-Type -TypeDefinition $code -CodeDomProvider $FSharpCodeProvider -ReferencedAssemblies $FakeLib  -IgnoreWarnings

    # Do something about it
    [FakeTest]
}

```

Hint
====

* To view available modules `Get-Module –ListAvailable`
* Show environment `Get-ChildItem env:`
* Where did FSharp.Compiler.CodeDom go? [https://github.com/fsprojects/powerpack-archive/issues/21](https://github.com/fsprojects/powerpack-archive/issues/21)
