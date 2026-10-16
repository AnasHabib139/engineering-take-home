# Symptom Diary: take-home task

## Hi there, and welcome 🖖

Thanks for taking the time to do this, we really appreciate it 💙

We're [Kranus Health](https://github.com/kranushealth). We build digital therapeutics: clinically
validated therapies that patients use as mobile apps, made together with our renowned in-house
medical team.

The diary app in this repo isn't one of our products, but it reflects the challenges our
engineering team works with every day:

- **Compliance and regulation:** as a digital therapy and a medical device, we work under several
  strict regulations, and features have to be built within them, not around them.
- **AI:** we build with coding agents every day, and we stay responsible for what they produce.
- **Our real stack:** FastAPI, PostgreSQL and Flutter, the same as in production.
- **End-to-end ownership:** one engineer takes a feature from the database to the app screen.
- **Real people:** patients open the app on good days and bad ones, so the details matter.

Never used Flutter? No problem, plenty of us learned it on the job. We care much more about how
you find your way around than about what you already know.

Use AI as much as you like, we do too. But as we say on our GitHub page: we love AI, and we like
using our brains even more. In the interview we'll go through your solution together, so build
something you'd happily walk a teammate through.

Patients record their mood and symptoms in a diary. Your job is to add one feature end to end, in
about 2 hours. Have fun! 🚀

## Setup (before you start the clock)

You only need **Docker** ([Docker Desktop](https://docs.docker.com/get-docker/) on macOS and
Windows, Docker Engine on Linux) and `make`. No Python or Flutter installation is needed.

- **macOS:** if `make` is missing, run `xcode-select --install`.
- **Linux:** `sudo apt install make` (or your distro's equivalent).
- **Windows:** use WSL2 with Docker Desktop's WSL integration turned on, and clone the repo
  inside WSL (e.g. `~/`), not under `/mnt/c`, which is slow and breaks auto-reload.

```bash
make setup   # one-off: checks prerequisites, downloads images (~4 GB), builds the app
make up      # app: http://localhost:28001   API docs: http://localhost:28000/docs
make test    # backend and app tests
make observe # Grafana: http://localhost:28003   Prometheus: http://localhost:28002
```

Nothing installed at all? Open the repo in **GitHub Codespaces**; the dev container runs
`make setup` for you. `make help` lists all commands.

## What's here

| Path | What |
| --- | --- |
| `backend/` | FastAPI app (`app/`), Alembic migrations, pytest tests |
| `app/` | Flutter app (built for the web; `make app` rebuilds it) |
| `app/DESIGN.md` | How the app looks; new screens follow it |
| `observability/` | Prometheus and Grafana config, dashboards |
| `BRIEF.md` | What to build, from the kick-off call |
| `API.md` | The endpoints other teams already rely on |
| `REQUIREMENTS.md` | Requirements your solution must meet |
| `NOTES.md` | Your notes; fill it in and commit it |

Authentication is a stub: send `Authorization: Bearer <role>-<id>`. The demo data has
`patient-1`, `patient-2`, `clinician-1` and `clinician-2`. The app always acts as `patient-1`.

## The task: "Share my diary with my doctor"

Start with `BRIEF.md`: notes from the kick-off call where product, medical, data protection and
mobile agreed what to build. Then:

1. Implement the endpoints in `API.md`.
2. Build the patient's side in the app: share the diary with a doctor, stop sharing, and see who
   looked at it. A doctor UI is not needed.
3. Help us know whether it works. Product wants to know if patients use sharing and keep
   logging; the on-call engineer wants to know when doctors can't open a diary. Pick at least
   one signal for each, build them in the backend or in the app (wherever you're comfortable),
   and write down in `NOTES.md` what you'd watch and when someone should act. The app can send
   events with `api.track()`, the backend has `/metrics`, and `make observe` gives you Grafana
   if you'd like to build a dashboard (optional).

Your solution has to meet our security and data protection requirements in `REQUIREMENTS.md`.
Not all of them apply to this feature: tell us in `NOTES.md` which ones do, and why.
Erasure (O.Del_1) is a stretch goal: if you don't build it, describe in `NOTES.md` how you would.

## How it works

- **Timebox: 2 hours.** Stop there and write in `NOTES.md` what you would do next.
- **Use any AI tools you like.** You must be able to explain everything you submit.
- If something is unclear, write down your assumption and carry on.
- Keep `make test` green and add tests for what you build. We also run our own tests against
  your API, so stick to `API.md`.
- Add 2–3 screenshots of your sharing screens to `NOTES.md` (and of your dashboard, if you
  build one).
- **Submit:** fork this repo, push your work to the fork, and send us the link.

In the on-site interview you will continue from your own submission, on your own laptop.

Stuck on setup? Reply to the email you got from us; setup problems are on us, not on you. Good luck, and see you in Munich 🍺 💙
