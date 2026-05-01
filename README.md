# Frostfire Quest Frames

An immersive quest and gossip dialogue replacement for **World of Warcraft: Wrath of the Lich King (3.3.5a enUS client)**.

I tried using some backports of popular quest frame immersion addons and they generally work great but wanted to try to make something for myself and spent a morning vibe coding my own version. The code very messy. The textures "borrowed" from some other projects, but for me it just works. If anyone wants to use this feel free. If anyone wants to clean this up be my guest. (A shoutout would be appreciated!)
---

## What It Does

Replaces the default quest and gossip windows with a more immersive dialogue experience:

- **Faction-themed backgrounds** — Horde, Alliance, or neutral background based on the NPC you're talking to, falling back to your player's faction if the NPC's can't be determined.
- **Live 3D model viewers** — your character and the NPC are displayed flanking the dialogue pane, mirroring their in-world appearance.
- **Animated conversation** — models play talk, question, nod, point, and other gestures back and forth while dialogue is open.
- **Parchment text area** — quest and gossip text is displayed on a centered parchment background.
- **Full gossip support** — works with quest givers, gossip NPCs, bankers, innkeepers, and other single-option NPCs that would normally skip the gossip frame.

---

## Commands

`/ffqf hide` — force close the frame  
`/ffqf reset` — reset internal sizing flags (use if layout looks wrong after UI reload)

---

## Credits & Inspiration

**Storyline** by Sylvain Cossement 
- Animation technique using `SetSequenceTime` driven by an OnUpdate loop, and the `playAndStand` pattern for returning models to idle after an animation completes
- WotLK 3.3.5a backport by Lanrutcon, Shadovv, and centurijon
- https://www.curseforge.com/wow/addons/storyline

**Immersion** by MunkDev
- https://www.curseforge.com/wow/addons/immersion

**DialogueUI**  by Peterdox
- For the parchment layout and overall dialogue aesthetic
- https://www.curseforge.com/wow/addons/dialogueui

**New Quest Frame** by: reative_pl
- For faction specific backgrounds
- https://www.wowinterface.com/downloads/info22317-NewQuestFrame.html

**Gossiper** by Wazzak  
- The `ForceGossip` override technique to prevent single-option NPCs from bypassing the gossip frame
- https://www.wowinterface.com/downloads/info22819-Gossiper.html

---

## Requirements

- World of Warcraft client version **3.3.5a** (Wrath of the Lich King - enUS). Will likely crash and burn with other clients.

---

## Installation

1. Extract the `FrostfireQuestFrames` folder into your `Interface/AddOns/` directory.
2. Reload your UI or log in.
3. The addon activates automatically whenever you interact with a quest giver or gossip NPC.

---

## Notes

- Addon tries to force open gossip options that the 3.3.5 client skips with only one option available. This causes issues. Instead I ForceGossip on startup. Could possibly be fixed but I prefer this behaivor. IMMERSION.
- Short freezes on models after playing animations. Had issues trying to resolve. Generally pretty reasonable to deal with.
- Designed for 1920x1080 resolution. Your milage may vary.
- Faction backgrounds are 1024x512 TGA format — you can replace `horde.tga`, `alliance.tga`, and `other.tga` in the `Art/` folder with your own artwork.
- The inner parchment (`ParchmentBG.tga`) is 512x512 and can also be replaced.
- All textures must be power-of-two dimensions and in TGA or BLP format.
