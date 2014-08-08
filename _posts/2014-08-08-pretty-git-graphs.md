---
layout: post
title: Pretty git branch graphs
---

[Source](http://stackoverflow.com/questions/1057564/pretty-git-branch-graphs)

I've seen some books and articles have some really pretty looking graphs of git branches and commits.
Is there any tool that can make high-quality printable images of git history?

[**2¢**](http://stackoverflow.com/users/177525/slipp-d-thompson): I have two aliases I normally throw in my ~/.gitconfig file:

{% highlight bash %}
    [alias]
    lg1 = log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
    lg2 = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all
    lg = !"git lg1"
{% endhighlight %}

`git lg/git lg1` looks like this:

![wow]({{ Site.url }}/public/git-lg1.png)

and git lg2 looks like this:

![wow]({{ Site.url }}/public/git-lg2.png)

for textual output you can try:

`git log --graph --oneline --all`
