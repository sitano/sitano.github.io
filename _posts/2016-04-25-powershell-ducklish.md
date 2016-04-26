---
layout: post
title: PowerShell ducklish typed
---

This is a quick write-up on quirks I have ran into with the PowerShell 
language. 

PowerShell is the only scripting solution on Windows platform. We run it a lot.
After scripts exceeded some volume in LOCs they have found out it self 
unmaintainable, untestable and error prone in general. 

Its even worse when you have to deal with DevOps, clouds and servers setup. 
Those environments are very unstable in the sense of various side effects
continuously happening all around across its structure. There is a big chance
you will end up every line of code breaking and throwing because of this. i.e.
any file operation can hang because of missing paths, security constraints,
opened handles and etc.

PowerShell makes it even harder when it comes to testing, because of its
unpredictable [duck typing](https://en.wikipedia.org/wiki/Duck_typing) system.
It have the same problems as Ruby and JavaScript usually ignorant by its fans.

Someone should give the same talk on PowerShell: 
[A lightning talk by Gary Bernhardt from CodeMash 2012](https://www.destroyallsoftware.com/talks/wat)

Stupidness
----------

Scripts are interpreted. That means a code line checked only when its run
`& { return 1; z@x#cv.1 }`. You will never know in advance is your code
even valid. Thus, to test your code you have to write tests which execute
every single line of code with its all conditional blocks.

Single array equivalent to single value `@(1) -eq 1 -eq '1'`.

Empty data can be reduced to $nulls like `$a = & { @() }; $a.GetType()`.

Data structures containing single value can be reduce to single values which
will broke your code `(& { @(1) }).GetType()`.

Empty [hashtable] is $true `@{} | Should Be $true`, even empty [hashtable] keys
set is $true `@{}.Keys | Should Be $true`, while anything else like empty 
string, zero or empty array: `'', 0, @()` casts to $false.

Strings automatically casts to number types: `'123' -eq 123 -eq [int]'123'`,
but `0 -eq $false`, `'0' -eq $true`.

Exact cast do not enable valid parsing: `[int]'123' -eq 123`, but
`[bool]'false' -eq $true`.

Before 5.0, Write-Host can't be redirected via IO redirection.

IO redirection is very limited.

IO redirection lose data across multiple context invocation sights.

Errors handling is ill. `Write-Error` semantics depends on global variables,
and can be overridden manually per call / context.

`Write-Error` can throw different types of exceptions.

Exceptions bubbling stop crossing ScriptBlock boundary:
`try { { Write-Error 'x' -ErrorAction Stop } | Out-Null; 1; } catch {}`. No
excuse for this. Yeah, PowerShell developers think its funny when things
changes symantic dynamically depending on context.

Sorry, - `{ throw "Error" } | Out-Null; 1` same exception redirection.

Preferences variables are not catched by closures.

Variables scoping is broken: `& { if ($true) { $a = 1 }; $a }`. Its
impossible to test function, whether its argument complete.

By default cmdlets like `Get-Item 'non-existing-file'; $true` will print
an error, but continue to execute!

And so on.
