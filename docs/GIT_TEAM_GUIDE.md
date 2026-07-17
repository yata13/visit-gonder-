# Git & GitHub Team Guide 🤝

How our team works on Visit Gondar together without breaking each other's code.
Written for beginners — follow the steps exactly and you will be fine.

---

## The golden rules

1. **Never work directly on `main`.** `main` is the version that always works.
2. **One branch = one task.** Fix login bug → one branch. New hotel filter → another branch.
3. **Pull before you start.** Always begin from the newest code.
4. **Small pull requests.** Easier to review, faster to merge, fewer conflicts.
5. **Never commit `.env`** or passwords. (Git already ignores them here.)

---

## One-time setup (each teammate)

```bash
# 1. Install Git: https://git-scm.com/downloads
# 2. Tell Git who you are (shows on your commits)
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# 3. Get the project
git clone https://github.com/yata13/visit-gonder-.git
cd visit-gonder-
```

The repo owner must invite teammates first:
**GitHub → repo page → Settings → Collaborators → Add people** (enter their GitHub username).

---

## Daily workflow — the 7 steps

### Step 1 — Start from fresh `main`

```bash
git checkout main        # go to the main branch
git pull origin main     # download the newest code
```

### Step 2 — Create your own branch

```bash
git checkout -b feature/hotel-search
```

Branch name style: `feature/...` for new things, `fix/...` for bug fixes.
Examples: `feature/amharic-events`, `fix/sos-button-crash`.

### Step 3 — Work normally

Edit files, run the app, test your change.

### Step 4 — Save your work (commit)

```bash
git status                       # see what you changed
git add .                        # stage everything you changed
git commit -m "Add hotel search by name and price"
```

Write commit messages that say **what the change does** — "Add hotel search",
not "update" or "changes".

Commit often! Every time something small works, commit. Commits are free save-points.

### Step 5 — Upload your branch

```bash
git push -u origin feature/hotel-search
```

(After the first push, just `git push` is enough on that branch.)

### Step 6 — Open a Pull Request (PR)

1. Go to the repo on GitHub — a yellow banner says
   **"feature/hotel-search had recent pushes → Compare & pull request"**. Click it.
   (Or: **Pull requests → New pull request**, pick your branch.)
2. Title = what it does. Description = what you changed + how you tested it.
3. On the right side, add a teammate under **Reviewers**.
4. Click **Create pull request**.

### Step 7 — Review and merge

- The reviewer reads the changed files, writes comments, and clicks **Approve**
  when it looks good.
- If they request changes: just fix the code, `git add . && git commit && git push` —
  the PR updates automatically. No new PR needed.
- After approval, click **Merge pull request** → **Confirm**.
- Delete the branch when GitHub offers (keeps the repo tidy).
- Everyone then runs `git checkout main && git pull origin main` to get the merged code.

---

## Keeping your branch up to date

If you work several days and `main` moved ahead of you, bring its changes in:

```bash
git checkout main
git pull origin main
git checkout feature/hotel-search
git merge main            # bring main's new code into YOUR branch
```

Do this **daily** on long branches — small merges are painless, giant ones hurt.

---

## Merge conflicts — don't panic

A conflict happens when two people edited the **same lines**. Git marks the file:

```text
<<<<<<< HEAD
your version of the line
=======
their version of the line
>>>>>>> main
```

Fix it in 3 steps:

1. Open the file, decide which version is right (or combine them),
   delete the `<<<<<<<`, `=======`, `>>>>>>>` lines.
2. `git add .` then `git commit`
3. `git push`

VS Code shows nice **"Accept Current / Accept Incoming / Accept Both"** buttons
for this — use them.

---

## Cheat sheet

| I want to… | Command |
|---|---|
| See what I changed | `git status` |
| See which branch I'm on | `git branch` |
| Switch branch | `git checkout branch-name` |
| New branch | `git checkout -b feature/thing` |
| Save work | `git add .` then `git commit -m "message"` |
| Upload | `git push` |
| Download newest main | `git checkout main` then `git pull origin main` |
| Update my branch with main | `git merge main` (while on your branch) |
| Undo changes to one file (careful!) | `git checkout -- path/to/file` |
| See history | `git log --oneline` |

---

## Protect `main` (repo owner, do once)

On GitHub: **Settings → Branches → Add branch ruleset**
- Ruleset name: `protect-main`, target branch: `main`, enforcement: Active
- Tick **Require a pull request before merging** (+ 1 approval)

Now nobody (including you) can accidentally push broken code straight to `main` —
everything goes through a reviewed pull request.
