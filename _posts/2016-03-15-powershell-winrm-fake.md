---
layout: post
title: Calling FAKE (F#) via WinRM from PowerShell
---

PowerShell is a dynamic language based on a subset of C# with extension
into Shell requirements. This language is the future of Windows based
servers administration and management.

Almost all popular Configuration Management Systems came from Linux
world like Puppet, Ansible, Salt, Chef, CF-engine and etc are weakly typed,
are based either on specific DSL or implementation Language. There is
not much in the Windows world. Microsoft always tend to provide their
own vendor locking solution and this time its not an exception: Desired
State Configuration system based on PowerShell.

Yet all those solutions struggles all the problems all dynamic languages have.
That means, that after making a change you can't be sure, if it is valid,
will it interpret or execute until you give 100% test coverage. PowerShell
in addition do not have static code analysis tools and do not protect
from errors like using undefined variables (or steeled from another scopes).

This leads to the problems of correctness, support and maintainability.
You never can be sure, until you run it.

In PowerShell case [Pester](https://github.com/pester/Pester) can help
providing TTD infrastructure like running framework, context, dsl, mocking,
etc.

I am sure this will change. Languages in the latest decade tend to evolve
in the direction of complex strong type systems, automatic memory management
and functional pureness. Following this logic, the community will see more
systems like [Propellor](https://github.com/joeyh/propellor) or
[FAKE](https://github.com/fsharp/FAKE) which tend to provide strong typed DSLs
based on underlying platform capabilities.

I was interested in researching of the state of strong typed systems around
PowerShell infrastructure from the POV of combining it with Windows Remote
Management system, which is popular in our practice and invaluable in whole
current Microsoft server strategy.

This is an overview of the method of combining PowerShell,
[Windows Remote Manager](https://msdn.microsoft.com/en-us/library/windows/desktop/aa384426.aspx)
[F#](http://fsharp.github.io/) and [FAKE](https://github.com/fsharp/FAKE).

Possible implementations of the Configuration Management System could be
based on following concepts:

- Given FSharp runtime, compiler and required libraries on every Target machine,
  system will pass F# scripts inside ScriptBlocks as simple text, remove compile
  them and execute directly via dynamic type resolving, interface cast and execution.

  - CodeDom in memory on demand compilation
  - Direct fsc.exe call
  - FSharp.Compiler.Services ?

- The system can compile locally on demand F# scripts, pass compiled assemblies
  any how to the target machine (via pssession, cloud storage, etc) and run them
  remotely.

  - fsc.exe, copy to remote site
  - direct injection of the assembly into pssession from []byte, instead of
    distribution

Personally, I would prefer to have the system which supports all modes of operations:

- Pass F# scripts as text via `Invoke-Command / PSSession` and executing and
  compiling them dynamically remotely on demand via existing remote infrastructure.
- To be able to execute locally compiled and prepared scripts batches to the
  remote site in the case of the preference. (omitting compilation should faster
  process at least)

[7 Configuration Management (CM) Tools You Need to Know About](
https://www.upguard.com/articles/the-7-configuration-management-tools-you-need-to-know)

`FAKE - F# Make` is a build automation system with capabilities which are similar to
make and rake. It is using an easy domain-specific language (DSL) so that you can
start using it without learning F. Combination of `FAKE` capabilities, DSL and
PowerShell remoting looks interesting combination.

Prepare FSharp compiler environment
===================================

During this process, I have met enormous amount of unstable effects and exceptions
amount Windows tooling and services which I intended not to resolve into the sake of
saving my time.

Use the following requirements and installation steps:

1.  Requires .NET 4.5:

    - On Windows 10 .NET 4.6 is already present by default
    - On Windows 8 and Windows 2012 Server, this is already present by default
    - On Windows 7 and Windows 2008 Server, [install .NET 4.5](http://www.microsoft.com/net/downloads) from Microsoft

2. Requires the Windows SDK:

    - On Windows 10 use the [Windows 10 and .NET 4.6 SDK](https://dev.windows.com/en-US/downloads/windows-10-sdk) from Microsoft
    - On Windows 8.1 use the [Windows 8.1 and .NET 4.5.1 SDK](http://msdn.microsoft.com/windows/desktop/bg162891) from Microsoft
    - On Windows 8 or Windows 2012 Server use the [Windows 8 and .NET 4.5 SDK](http://msdn.microsoft.com/windows/hardware/hh852363.aspx) from Microsoft
    - On Windows 7 or Windows 2008 Server use the [Windows 7 and .NET 4.0 SDK](http://www.microsoft.com/download/details.aspx?id=8279) from Microsoft

3. Requires Microsoft Build Tools 2015 - [Install Microsoft Build Tools 2015](https://www.microsoft.com/en-us/download/details.aspx?id=48159)

4. [Install the free Visual F# Tools 4.0](https://www.microsoft.com/en-us/download/details.aspx?id=48179) from Microsoft

Test your PowerShell CLR environment
------------------------------------

Check `$PSVersionTable`.

If its not 4.0, there are two ways to tell PowerShell version 2.0 to utilize
.NET Framework 4.

You’ll want to create powershell.exe.config and powershell_ise.exe.config and
place them in your $pshome directory.

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

or google for `PowerShell .NET 4.0`. [src](
http://www.adminarsenal.com/admin-arsenal-blog/powershell-running-net-4-with-powershell-v2/)

Test your WinRM environment
---------------------------

```powershell
Invoke-Command -ComputerName SECOND -ScriptBlock { Write-Output $env:COMPUTERNAME }
```

Microsoft Build Tools 2015
--------------------------

I have tried to install from [Microsoft Build Tools 2015](https://go.microsoft.com/fwlink/?LinkId=615458)
with:

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    $webclient = New-Object Net.WebClient
    $url = 'https://go.microsoft.com/fwlink/?LinkId=615458'
    $webclient.DownloadFile($url, "$pwd\BuildTools_Full.exe")
    .\BuildTools_Full.exe /Quiet /Full
}

```

and it did not work for me. Don't know why.

`FSharp` codedom
----------------

Latest version of nuget `FSharp.Compiler 4.4.0.0` is not compatible to `CodeDom 0.9.4`.

If you are using nuget, to install `FSharp.Core` to the remote site, the `4.3.1.0`
will be fine for `CodeDom 0.9.4`. Nonetheless I have failed to run fsharp compiler from
the nuget package due to some magical mscorlib.dll incompatibilities and some others
unresolved issues.

If you use nuget to provide a compiler, don't forget to include path the `tools`
directory (with fsc / fsi) into the $env:PATH.

```powershell

Invoke-Command -ComputerName SECOND -ScriptBlock {
    $webclient = New-Object Net.WebClient
    $url = 'http://download.microsoft.com/download/9/1/2/9122D406-F1E3-4880-A66D-D6C65E8B1545/FSharp_Bundle.exe'
    $webclient.DownloadFile($url, "$pwd\FSharp_Bundle.exe")
    .\FSharp_Bundle.exe /install /quiet
}

```

This will take some time.

Test `CodeDom`
--------------

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

Use `fake`
----------

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

Conclusion
==========

I have managed to successfully execute remote F# on demand compilation with FAKE
libraries on dependencies, what proves the concept as valid. Thus, mentioned kind of
strong typed DSL is possible to implement with integration with WinRM and PowerShell
to build good CM system for Windows platform.

Due to the very complex toolset required for the compilation of the script, inability
of these tools to be deployed smoothly in quite mode remotely, big time required for the
dynamically loaded compiler to initialise it self and actually do the compilation, I think
it makes more sense to execute only locally compiled scripts, configurations and batches
providing to the remote site only binary modules to run.

Hints
=====

* To view available modules `Get-Module –ListAvailable`
* Show environment `Get-ChildItem env:`
* Where did FSharp.Compiler.CodeDom go?
  [GitHub PowerPack archive issue 21](https://github.com/fsprojects/powerpack-archive/issues/21)

Links
=====

Its based on the following articles:

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
