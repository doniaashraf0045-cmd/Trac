"""Tests for the Phone Breaker Extreme game engine."""

import pytest
from game import Phone, GameSession, ATTACKS


class TestPhone:
    def test_initial_state(self):
        phone = Phone()
        assert phone.hp == phone.max_hp
        assert phone.destruction_percent == 0
        assert phone.condition == "Brand New"
        assert not phone.is_destroyed
        assert phone.broken_parts == []
        assert phone.cracks == 0

    def test_take_damage_reduces_hp(self):
        phone = Phone()
        for attack_name in ATTACKS:
            result = phone.take_damage(attack_name)
            assert result is not None
            assert result["damage"] > 0
            assert result["hp_remaining"] == phone.hp
            if phone.is_destroyed:
                break

    def test_take_damage_returns_correct_keys(self):
        phone = Phone()
        result = phone.take_damage("Smash")
        assert set(result.keys()) == {
            "attack", "emoji", "description",
            "damage", "critical", "hp_remaining", "destruction_percent",
        }
        assert result["attack"] == "Smash"
        assert isinstance(result["critical"], bool)

    def test_phone_cannot_go_below_zero_hp(self):
        phone = Phone()
        phone.hp = 1
        phone.take_damage("Explosion")
        assert phone.hp >= 0

    def test_phone_is_destroyed_when_hp_reaches_zero(self):
        phone = Phone()
        phone.hp = 0
        phone.is_destroyed = True
        assert phone.destruction_percent == 100
        assert phone.condition == "COMPLETELY DESTROYED"

    def test_no_damage_after_destruction(self):
        phone = Phone()
        phone.hp = 1
        # Drive the phone to 0 HP
        while not phone.is_destroyed:
            phone.take_damage("Hammer")
        result = phone.take_damage("Smash")
        assert result is None

    def test_destruction_percent_increases_with_damage(self):
        phone = Phone()
        prev = phone.destruction_percent
        phone.take_damage("Hammer")
        assert phone.destruction_percent >= prev

    def test_condition_labels(self):
        phone = Phone()
        phone.hp = phone.max_hp          # 0%
        assert phone.condition == "Brand New"
        phone.hp = int(phone.max_hp * 0.85)   # ~15%
        assert phone.condition == "Slightly Scratched"
        phone.hp = int(phone.max_hp * 0.65)   # ~35%
        assert phone.condition == "Cracked"
        phone.hp = int(phone.max_hp * 0.45)   # ~55%
        assert phone.condition == "Heavily Damaged"
        phone.hp = int(phone.max_hp * 0.25)   # ~75%
        assert phone.condition == "Barely Holding Together"
        phone.hp = int(phone.max_hp * 0.05)   # ~95%
        assert phone.condition == "Nearly Destroyed"
        phone.hp = 0
        assert phone.condition == "COMPLETELY DESTROYED"

    def test_get_visual_returns_string(self):
        phone = Phone()
        visual = phone.get_visual()
        assert isinstance(visual, str)
        assert len(visual) > 0

    def test_get_visual_changes_with_destruction(self):
        phone = Phone()
        visual_new = phone.get_visual()
        phone.hp = 0
        visual_destroyed = phone.get_visual()
        assert visual_new != visual_destroyed

    def test_cracks_increment_each_hit(self):
        phone = Phone()
        phone.take_damage("Smash")
        assert phone.cracks == 1
        phone.take_damage("Throw")
        assert phone.cracks == 2


class TestGameSession:
    def test_initial_state(self):
        session = GameSession()
        assert session.phones_destroyed == 0
        assert session.total_damage == 0
        assert session.total_attacks == 0
        assert session.critical_hits == 0
        assert session.current_phone is not None

    def test_record_hit_accumulates_stats(self):
        session = GameSession()
        result = session.current_phone.take_damage("Smash")
        session.record_hit(result)
        assert session.total_attacks == 1
        assert session.total_damage == result["damage"]
        assert session.attack_counts["Smash"] == 1

    def test_record_hit_counts_criticals(self):
        session = GameSession()
        # Fake a critical hit result
        fake_result = {
            "attack": "Smash",
            "emoji": "👊",
            "description": "test",
            "damage": 99,
            "critical": True,
            "hp_remaining": 401,
            "destruction_percent": 19.8,
        }
        session.record_hit(fake_result)
        assert session.critical_hits == 1

    def test_record_hit_ignores_none(self):
        session = GameSession()
        session.record_hit(None)
        assert session.total_attacks == 0

    def test_next_phone_increments_destroyed_count(self):
        session = GameSession()
        session.current_phone.is_destroyed = True
        session.next_phone()
        assert session.phones_destroyed == 1
        assert not session.current_phone.is_destroyed

    def test_next_phone_without_destruction_does_not_count(self):
        session = GameSession()
        session.next_phone()
        assert session.phones_destroyed == 0

    def test_get_stats_summary_keys(self):
        session = GameSession()
        stats = session.get_stats_summary()
        required = {
            "phones_destroyed", "total_damage", "total_attacks",
            "critical_hits", "elapsed", "attack_counts", "favorite_attack",
        }
        assert required.issubset(set(stats.keys()))

    def test_favorite_attack_no_attacks(self):
        session = GameSession()
        stats = session.get_stats_summary()
        assert stats["favorite_attack"] == "None"

    def test_favorite_attack_reflects_most_used(self):
        session = GameSession()
        for _ in range(3):
            result = session.current_phone.take_damage("Hammer")
            if result:
                session.record_hit(result)
        result = session.current_phone.take_damage("Smash")
        if result:
            session.record_hit(result)
        stats = session.get_stats_summary()
        assert stats["favorite_attack"] == "Hammer"

    def test_elapsed_time_format(self):
        session = GameSession()
        stats = session.get_stats_summary()
        # Should be MM:SS format
        assert ":" in stats["elapsed"]
        parts = stats["elapsed"].split(":")
        assert len(parts) == 2
        assert parts[0].isdigit()
        assert parts[1].isdigit()


class TestAttacks:
    def test_all_attacks_have_required_keys(self):
        for name, info in ATTACKS.items():
            assert "damage" in info, f"{name} missing 'damage'"
            assert "description" in info, f"{name} missing 'description'"
            assert "emoji" in info, f"{name} missing 'emoji'"

    def test_damage_ranges_are_valid(self):
        for name, info in ATTACKS.items():
            min_dmg, max_dmg = info["damage"]
            assert min_dmg > 0, f"{name} min damage must be positive"
            assert max_dmg >= min_dmg, f"{name} max damage must be >= min damage"

    def test_damage_within_range(self):
        """Each attack's actual damage should be within its declared range."""
        import random
        random.seed(42)
        phone = Phone()
        for attack_name, info in ATTACKS.items():
            if phone.is_destroyed:
                phone = Phone()
            result = phone.take_damage(attack_name)
            if result is None:
                continue
            min_dmg, max_dmg = info["damage"]
            # Critical hits can go up to 1.5x max_dmg
            assert result["damage"] >= min_dmg
            assert result["damage"] <= int(max_dmg * 1.5)
