# Custom Fork Maintenance

This fork keeps custom UI work on `custom/project-tabs` and treats `master` as the upstream mirror for `warpdotdev/warp`.

## Manual Sync

Run from the repository root:

```powershell
.\script\sync-upstream.ps1
```

To push successful updates to `origin`:

```powershell
.\script\sync-upstream.ps1 -Push
```

The script:

- refuses to run with uncommitted changes
- fetches `origin` and `upstream`
- rebases `master` onto `upstream/master`
- rebases `custom/project-tabs` onto `upstream/master`
- enables `git rerere` so repeated conflict resolutions can be reused
- pushes only when `-Push` is passed

If a rebase conflict happens, resolve it normally, then run:

```powershell
git add <resolved-files>
git rebase --continue
```

After the rebase completes, rerun the sync script.
