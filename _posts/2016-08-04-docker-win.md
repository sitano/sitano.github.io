---
layout: post
title: Docker Windows install instructions on the state of 4 August 2016
---

Configuration of Windows 10 / Windows Server 2016 TP5 requires few specific steps
to be done in order to make Docker work. This is detailed description of the setup sequence.

Another Solution
----------------

Prepared _Windows Server 2016 TP5_ with everything on-board image can be build
with [Packer](https://www.packer.io/) using
[@StefanScherer's github.com/docker-windows-box](https://github.com/StefanScherer/docker-windows-box).
Its possible to build VirtualBox, VMWare or Hyper-V image. Configuration scripts
sits in [https://github.com/StefanScherer/docker-windows-box/tree/master/scripts](https://github.com/StefanScherer/docker-windows-box/tree/master/scripts).

Step-by-step guide
==================

1. Hyper-V setup: In order to connect the VM to the internet configure:
   _External_ virtual switch in Shared control mode.
   There is also an opportunity to use _Internal_ switch with _NAT_ enabled over.
   1. [Run Hyper-V in a Virtual Machine with Nested Virtualization](https://msdn.microsoft.com/en-us/virtualization/hyperv_on_windows/user_guide/nesting)
1. Download latest
  1. Windows 10 and install latest [August 2, 2016 — KB3176929 (OS Build 14393.10)](https://support.microsoft.com/). ([https://support.microsoft.com/en-us/help/12387/windows-10-update-history](https://support.microsoft.com/en-us/help/12387/windows-10-update-history))  
  1. or: Windows Server 2016 TP5 from Insider program _(min insiders build 14372)_ [https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview)
    1. Use Standard Key: `MFY9F-XBN2F-TYFMP-CCV49-RMYVH` from Preinstallation instructions in order to do basic install.
    1. Default password policy requires to enter Administrator Password to contain: Big letters, Small letters, Digits.  
    1. Using Local Security Policy - disable strict password policy.
      1. `GPO_name\Computer Configuration\Windows Settings\Security Settings\Account Policies\Password Policy`
      1. [Password must meet complexity requirements](https://technet.microsoft.com/en-us/library/hh994562(v=ws.11).aspx)
    1. Using Local Security Policy - allow running Edge under Administrator.
      1. Under _Local Policies/Security Options_ navigate to _“User Account Control Admin Approval Mode for the Built-in Administrator account“_
      1. Set the policy to _Enabled_
      1. [Windows 10 Edge can’t be opened using the built-in administrator account](http://www.virtualizationhowto.com/2015/07/windows-10-edge-opened-builtin-administrator-account/)
1. Enable updates, Enable Insider Mode, [Enable Developer Mode](http://www.ghacks.net/2015/06/13/how-to-enable-developer-mode-in-windows-10-to-sideload-apps/)
1. Install Hyper-V Feature
  1. [Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All](https://msdn.microsoft.com/en-us/virtualization/windowscontainers/docker/configure_docker_daemon)
1. Install Containers Feature
  1. [Enable-WindowsOptionalFeature -Online -FeatureName containers -All](https://msdn.microsoft.com/en-us/virtualization/windowscontainers/quick_start/quick_start_windows_10)
  1. `Set-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\Containers' -Name VSmbDisableOplocks -Type DWord -Value 1 -Force`
1. Install Docker
  1. `New-Item -Type Directory -Path "C:\Program Files\docker\"`
  1. `Invoke-WebRequest https://master.dockerproject.org/windows/amd64/dockerd.exe -OutFile $env:ProgramFiles\docker\dockerd.exe`
  1. `Invoke-WebRequest https://master.dockerproject.org/windows/amd64/docker.exe -OutFile $env:ProgramFiles\docker\docker.exe`
  1. `[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:ProgramFiles\docker\", [EnvironmentVariableTarget]::Machine)`
  1. `& $env:ProgramFiles\docker\dockerd.exe --register-service`
1. Configure Docker daemon
  1. `net localgroup docker /add`
  1. `net localgroup docker Administrator /add`
  1. `Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\docker -Name ImagePath -Value "``"C:\Program Files\docker\dockerd.exe``" --run-service -H npipe:// -H tcp://0.0.0.0:2375 -G docker -D"``
  1. `Start-Service Docker`
1. Check Docker
  1. `docker version`
  1. `docker info`
1. Fetch Docker logs
  1. `Get-EventLog -LogName Application -Source Docker -After (Get-Date).AddMinutes(-5) | Sort-Object TimeGenerated`
1. Download default images depending on your host type (nano or gui)
  1. `Set-ExecutionPolicy Bypass -scope Process`
  1. `Install-PackageProvider ContainerImage -Force`
  1. Install image
    1. `Install-ContainerImage -Name WindowsServerCore` (obsolete)
    1. or: `Install-ContainerImage -Name NanoServer` (obsolete)
    1. or: `Start-BitsTransfer https://aka.ms/tp5/6b/docker/nanoserver -Destination nanoserver.tar.gz; docker load -i nanoserver.tar.gz` (obsolete)
    1. or: `docker pull microsoft/nanoserver:10.0.14300.1030` (for Windows 10, Windows Server 2016 Nano)
    1. or: `docker pull microsoft/windowsservercore:10.0.14300.1030` (for Windows Server 2016)
  1. `Restart-Service docker`
  1. `docker tag microsoft/windowsservercore:10.0.14300.1030 windowsservercore:latest`
1. Deploy your first container
  1. `docker run -it windowsservercore ping -t localhost`
  1. or: `docker run -it nanoserver ping -t localhost`
1. Docker machine install
  1. Install Chocolatey `& iex (wget 'https://chocolatey.org/install.ps1' -UseBasicParsing)`, `rm $profile`
  1. `choco install -y docker-machine`
  1. `choco install -y docker-compose`

Related Articles
================
- [TechNet Evaluation Center Windows Server 2016 Technical Preview 5 Evaluations](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview)
- [Different ways for installing Windows features on the command line](https://peter.hahndorf.eu/blog/WindowsFeatureViaCmd)
- [How to Configure Network Settings on a Hyper-V Host in VMM](https://technet.microsoft.com/en-us/library/gg610603(v=sc.12).aspx)
- [Manage the Hyper-V Hosts - Set up a NAT network](https://msdn.microsoft.com/en-us/virtualization/hyperv_on_windows/user_guide/setup_nat_network)
- [Run Hyper-V in a Virtual Machine with Nested Virtualization](https://msdn.microsoft.com/en-us/virtualization/hyperv_on_windows/user_guide/nesting)
- [Containers Quick Start - Windows Containers on Windows Server](https://msdn.microsoft.com/en-us/virtualization/windowscontainers/quick_start/quick_start_windows_server)
- [Containers Quick Start - Windows Containers on Windows 10](https://msdn.microsoft.com/en-us/virtualization/windowscontainers/quick_start/quick_start_windows_10)
- [Docker on Windows - Docker Daemon on Windows](https://msdn.microsoft.com/en-us/virtualization/windowscontainers/docker/configure_docker_daemon)

Related Issues
==============

- [github@docker/25176](https://github.com/docker/docker/issues/25176)
- [github@docker/25336](https://github.com/docker/docker/issues/25336)
