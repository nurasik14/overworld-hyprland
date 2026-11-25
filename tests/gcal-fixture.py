#!/usr/bin/env python3
"""gcal-fixture.py — fictional Google-Calendar events, relative to today, in the format of google_api.py `calendar list`.
For the offscreen renders and tests of the Clock & Calendar card (nothing here is a real event).
  gcal-fixture.py [--soon] [--busy]     --soon: the lab starts in 10 minutes   --busy: 8 events on day +2 (the tooltip's "+N more")
"""
import json
import sys
from datetime import datetime, timedelta

soon = "--soon" in sys.argv
now = datetime.now().astimezone()
t0 = now.replace(hour=0, minute=0, second=0, microsecond=0)
out = []


def timed(day, hm, mins, title, loc="", desc=""):
    s = t0 + timedelta(days=day, hours=hm[0], minutes=hm[1])
    out.append({"id": "fx%d" % len(out), "summary": title, "start": s.isoformat(timespec="seconds"),
                "end": (s + timedelta(minutes=mins)).isoformat(timespec="seconds"), "location": loc, "description": desc,
                "status": "confirmed", "htmlLink": "https://example.invalid/event/%d" % len(out)})


def allday(day, days, title):
    s = (t0 + timedelta(days=day)).date()
    out.append({"id": "fx%d" % len(out), "summary": title, "start": s.isoformat(), "end": (s + timedelta(days=days)).isoformat(),
                "location": "", "description": "", "status": "confirmed", "htmlLink": "https://example.invalid/event/%d" % len(out)})


timed(0, (8, 30), 90, "[class] Linear Algebra lecture", "LT-3", "Chapter 7: eigenvalues")
if soon:
    s = now + timedelta(minutes=10)
    out.append({"id": "fx%d" % len(out), "summary": "[class] Programming lab", "start": s.replace(second=0, microsecond=0).isoformat(timespec="seconds"),
                "end": (s + timedelta(minutes=60)).replace(second=0, microsecond=0).isoformat(timespec="seconds"), "location": "MMW 2450",
                "description": "Bring the laptop", "status": "confirmed", "htmlLink": "https://example.invalid/event/lab"})
else:
    timed(0, (11, 0), 60, "[class] Programming lab", "MMW 2450", "Bring the laptop")
timed(0, (16, 0), 60, "[opp] Apply: summer internship (Acme Robotics)", "", "Deadline Friday")
timed(0, (18, 30), 30, "[email] Reply to the chess society")
allday(0, 1, "Library book due")
allday(3, 2, "Hackathon weekend")
timed(1, (14, 0), 90, "Study group", "Library 3F")
timed(1, (19, 0), 60, "[weird] Unknown prefix event")
timed(2, (9, 0), 60, "[class] Calculus tutorial", "LT-1")
timed(5, (14, 0), 120, "[exam] Calculus midterm", "Exam Hall B", "Closed book. Bring student ID.")
timed(-2, (10, 0), 60, "[class] Past lecture")
timed(-1, (15, 0), 45, "Dentist")
allday(7, 1, "Reading week starts")
timed(9, (12, 30), 60, "Lunch with the club")
if "--busy" in sys.argv:
    for i, (hm, title) in enumerate([((8, 0), "[class] Morning lecture"), ((9, 30), "Group project sync"), ((11, 0), "[class] Lab session"),
                                      ((12, 30), "Lunch"), ((14, 0), "[opp] Info session"), ((15, 30), "Gym"), ((17, 0), "[email] Send the report"),
                                      ((19, 0), "Movie night")]):
        timed(2, hm, 50, title)
    allday(2, 1, "Tuition due")
json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
