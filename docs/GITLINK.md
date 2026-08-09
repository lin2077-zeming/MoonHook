# GitLink 同步说明

GitLink 仓库需要与 GitHub 仓库保持同步。你只需在 GitLink 上创建一个空仓库，
然后执行下面的脚本即可把 `main` 分支推送到 GitLink：

```powershell
.\scripts\mirror-to-gitlink.ps1 -GitLinkUrl "https://gitlink.org.cn/<用户名>/MoonHook.git"
```

等价的手动命令：

```bash
git remote add gitlink https://gitlink.org.cn/<用户名>/MoonHook.git
git push -u gitlink main
```

如果希望每次推送到 GitHub 后自动同步 GitLink，可以在 GitLink 后台生成一个
Personal Access Token，把它配置为 GitHub 仓库的 `GITLINK_TOKEN` secret，
再参考本目录或 GitHub Actions 文档添加 mirror 工作流。
