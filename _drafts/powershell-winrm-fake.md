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
