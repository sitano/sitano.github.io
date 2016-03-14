---
layout: post
title: Using FAKE (F#) via WinRM with PowerShell
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

Test your WinRM environment:

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock { Write-Output $env:COMPUTERNAME }

```

Provide `FSharp` environment:

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    # Cache
    $tools = 'C:\Tools'

    if (-not (Test-Path -Path $tools)) {
        New-Item -Path $tools -ItemType 'directory'
    }

    Set-Location $tools

    # Libs
    @('MSBuild',
      'FSharp.Core',
      'FSharp.Core.Extra',
      'FSharp.Compiler.Service',
      'FSharp.Compiler.Tools',
      'FSharp.Compiler.CodeDom') | ? {
        -not (Get-ChildItem -Path (Join-Path -Path $tools -ChildPath "$_*"))
      } | % {
        nuget install $_
      }

    # Include
    Get-ChildItem -Path C:\Tools\MSBuild.*\tools\Windows\*.dll | % { Add-Type -Path $_.FullName }
    Get-ChildItem -Path C:\Tools\FSharp.Core.*\lib\net40\FSharp.Core.dll | % { Add-Type -Path $_.FullName }
    Get-ChildItem -Path C:\Tools\FSharp.Compiler.Tools.*\tools\*.dll | % { Add-Type -Path $_.FullName }
    Get-ChildItem -Path C:\Tools\FSharp.Compiler.CodeDom.*\lib\net40\FSharp.Compiler.CodeDom.dll | % { Add-Type -Path $_.FullName }

    #example of calling -TypeDefinition
    $fibCode = @"
        module Fibonacci
        let fibs =
            (1,1) |> Seq.unfold
                (fun (n0,n1) ->
                    Some(n0, (n1, n0 + n1)))
        let get n =
            Seq.item n fibs
    "@

    # Compile
    # If you get Microsoft.Build.Utilities.Core, Version=14.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a error
    # install Microsoft Build Tools 2015 from https://go.microsoft.com/fwlink/?LinkId=615458
    # it can be installed quietly using: /Quiet /Silent /NoRestart /Full.
    # This should be fixed by using MSBuild 0.1.2 in the future.
    $FSharpCodeProvider = New-Object FSharp.Compiler.CodeDom.FSharpCodeProvider
    Add-Type -TypeDefinition $fibCode -CodeDomProvider $FSharpCodeProvider

    # Test
    [Fibonacci]::get(5)
}

```

Provide `fake`:

```powershell

      'FAKE'

    ...

    Get-ChildItem -Path C:\Tools\Fake.*\tools\FakeLib.dll | % { Add-Type -Path $_.FullName }


```

Hint
====

* To view available modules `Get-Module –ListAvailable`
* Show environment `Get-ChildItem env:`
* Where did FSharp.Compiler.CodeDom go? [https://github.com/fsprojects/powerpack-archive/issues/21](https://github.com/fsprojects/powerpack-archive/issues/21)
