"""Spell descriptions for the magic shops (owner, 2026-11-25: format B, docs/ff1-magic-descriptions.md):
what the spell does with its number, who it reaches and when it can be cast, and a note when one helps.
Our own text (no game data); shown at once in the shop's speech window while the hand is on a spell.
Spells in FF1's order (level 1-8, four white then four black); at most 4 lines of 18 columns."""
import text

SDESC_BANK = 120

DESC = [
    ('Cure', ('HP +16-32', '1 ally, any time')),
    ('Dia', ('Holy 20-40 dmg', 'All foes, battle', 'Undead only')),
    ('Protes', ('Defense +8', '1 ally, battle', 'Lasts the battle')),
    ('Blink', ('Evasion +80', 'Self, battle', 'Lasts the battle')),
    ('Fire', ('Fire 10-20 dmg', '1 foe, battle', 'x1.5 if weak')),
    ('Sleep', ('Sleep', 'All foes, battle', 'Skips its turns')),
    ('Shape', ('Evasion -20', '1 foe, battle', 'Easier to hit')),
    ('Thunder', ('Bolt 10-20 dmg', '1 foe, battle', 'x1.5 if weak')),
    ('Blindna', ('Cures Blind', '1 ally, battle')),
    ('Silence', ('Silence', 'All foes, battle', 'No more spells')),
    ('Thunder Barrier', ('Resist lightning', 'Party, battle', 'Halves bolt dmg')),
    ('Invisible', ('Evasion +40', '1 ally, battle', 'Lasts the battle')),
    ('Blizzard', ('Ice 20-40 dmg', '1 foe, battle', 'x1.5 if weak')),
    ('Darkness', ('Blind', 'All foes, battle', 'Attacks miss more')),
    ('Strike', ('Attack +14', '1 ally, battle', 'Lasts the battle')),
    ('Slow', ('Fewer attacks', 'All foes, battle', 'Fewer hits a turn')),
    ('Cura', ('HP +33-66', '1 ally, any time')),
    ('Adia', ('Holy 40-80 dmg', 'All foes, battle', 'Undead only')),
    ('Fire Barrier', ('Resist fire', 'Party, battle', 'Halves fire dmg')),
    ('Heal', ('HP +12-24 each', 'Party, any time')),
    ('Fira', ('Fire 30-60 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Hold', ('Paralysis', '1 foe, battle', 'Cannot act')),
    ('Thundara', ('Bolt 30-60 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Shapera', ('Evasion -20', 'All foes, battle', 'Easier to hit')),
    ('Poisona', ('Cures Poison', '1 ally, any time')),
    ('Fear', ('Fear', 'All foes, battle', 'Foes may run')),
    ('Cold Barrier', ('Resist ice', 'Party, battle', 'Halves ice dmg')),
    ('Vocal', ('Cures Silence', '1 ally, battle', 'Can cast again')),
    ('Sleepra', ('Sleep', '1 foe, battle', 'Surer than Sleep')),
    ('Haste', ('Attacks x2', '1 ally, battle', 'Lasts the battle')),
    ('Confuse', ('Confusion', 'All foes, battle', 'Acts at random')),
    ('Blizzara', ('Ice 40-80 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Curada', ('HP +66-132', '1 ally, any time')),
    ('Raise', ('Revive, 1 HP', '1 ally, field only')),
    ('Dadia', ('Holy 60-120 dmg', 'All foes, battle', 'Undead only')),
    ('Heala', ('HP +48-96 each', 'Party, any time')),
    ('Firaga', ('Fire 50-100 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Clouda', ('Instant death', 'All foes, battle', 'Poison-proof: safe')),
    ('Teleport', ('Up one floor', 'Party, field only', 'Dungeons only')),
    ('Raslow', ('Fewer attacks', '1 foe, battle', 'Fewer hits a turn')),
    ('Stona', ('Cures Stone', '1 ally, field only')),
    ('Escape Teleport', ('Exit dungeon', 'Party, field only', 'Back to the map')),
    ('Protea', ('Defense +12 each', 'Party, battle', 'Lasts the battle')),
    ('Invisia', ('Evasion +40 each', 'Party, battle', 'Lasts the battle')),
    ('Thundaga', ('Bolt 60-120 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Death', ('Instant death', '1 foe, battle', 'Death-proof: safe')),
    ('Quake', ('Instant death', 'All foes, battle', 'Fliers are safe')),
    ('Stun', ('Paralysis', '1 foe, battle', 'Foe under 300 HP')),
    ('Curaga', ('HP to full', '1 ally, any time', 'Cures ailments')),
    ('Gadia', ('Holy 80-160 dmg', 'All foes, battle', 'Undead only')),
    ('Magic Barrier', ('Resist status', 'Party, battle', 'And death, quake')),
    ('Raheala', ('HP +48-96 each', 'Party, any time')),
    ('Blizzaga', ('Ice 70-140 dmg', 'All foes, battle', 'x1.5 if weak')),
    ('Break', ('Stone', '1 foe, battle', 'Gone for good')),
    ('Saber', ('Attack +16', 'Self, battle', 'Lasts the battle')),
    ('Blind', ('Blind', '1 foe, battle', 'Foe under 300 HP')),
    ('Arise', ('Revive, full HP', '1 ally, field only')),
    ('Holy', ('Holy 80-160 dmg', 'All foes, battle', 'No element')),
    ('All Barrier', ('Resist all', '1 ally, battle', 'Every element')),
    ('Dispel', ('Resists removed', '1 foe, battle', 'Then strike hard')),
    ('Flare', ('100-200 dmg', 'All foes, battle', 'No element')),
    ('Stop', ('Paralysis', 'All foes, battle', 'Time magic')),
    ('Dejon', ('Instant death', 'All foes, battle', 'Time magic')),
    ('Kill', ('Instant death', '1 foe, battle', 'Foe under 300 HP')),
]


def bank():
    """64 pointers at $4000, then the texts (lines joined by $0A, ended by 0)"""
    assert len(DESC) == 64
    out = bytearray(128)
    for i, (name, lines) in enumerate(DESC):
        assert 1 <= len(lines) <= 4 and all(len(l) <= 18 for l in lines), name
        p = 0x4000 + len(out)
        out[2 * i] = p & 0xFF
        out[2 * i + 1] = p >> 8
        out += bytes(0x0A if ch == '\n' else text.code_of(ch) for ch in '\n'.join(lines)) + b'\0'
    assert len(out) <= 0x4000
    return bytes(out) + bytes(0x4000 - len(out))
