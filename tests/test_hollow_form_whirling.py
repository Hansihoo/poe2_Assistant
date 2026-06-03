import pathlib
import re


ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_hollow_form_support_maps_speed_and_damage_correctly() -> None:
    text = (ROOT / "src" / "Data" / "Skills" / "other.lua").read_text()

    assert re.search(
        r'\["mantra_of_illusions_triggered_skill_attack_speed_\+%_final"\]\s*=\s*\{\s*'
        r'mod\("Speed",\s*"MORE",\s*nil,\s*ModFlag\.Attack\)',
        text,
    )
    assert re.search(
        r'\["mantra_of_illusions_triggered_skill_damage_\+%_final"\]\s*=\s*\{\s*'
        r'mod\("Damage",\s*"MORE",\s*nil\)',
        text,
    )


def test_hollow_form_whirling_removes_only_whirling_total_attack_time() -> None:
    text = (ROOT / "src" / "Modules" / "CalcOffence.lua").read_text()

    assert "SkillType.SupportedByHollowForm" in text
    assert 'activeSkill.activeEffect.grantedEffect.id == "WhirlingAssaultPlayer"' in text
    assert 'value.mod.source == "Skill:WhirlingAssaultPlayer"' in text
    assert re.search(r"getTotalAttackTime\(activeSkill,\s*cfg\)", text)


def test_hollow_form_whirling_uses_hollow_form_attack_speed_multiplier() -> None:
    text = (ROOT / "src" / "Modules" / "CalcOffence.lua").read_text()

    assert "getHollowFormAttackSpeedMultiplier" in text
    assert 'supportEffect.grantedEffect.id == "SupportHollowFormPlayer"' in text
    assert "data.skills.MetaHollowFormPlayer" in text
    assert re.search(
        r"local attackSpeedMultiplier = getHollowFormAttackSpeedMultiplier\(activeSkill\) "
        r"or skillData\.attackSpeedMultiplier",
        text,
    )
