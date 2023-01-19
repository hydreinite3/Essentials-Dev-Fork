#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("RedirectAllMovesToUser",
  proc { |score, move, user, ai, battle|
    # Useless if there is no ally to redirect attacks from
    next Battle::AI::MOVE_USELESS_SCORE if user.battler.allAllies.length == 0
    # Prefer if ally is at low HP and user is at high HP
    if user.hp > user.totalhp * 2 / 3
      ai.each_ally(user.index) do |b, i|
        score += 10 if b.hp <= b.totalhp / 3
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("RedirectAllMovesToTarget",
  proc { |score, move, user, target, ai, battle|
    if target.opposes?(user)
      # Useless if target is a foe but there is only one foe
      next Battle::AI::MOVE_USELESS_SCORE if target.battler.allAllies.length == 0
      # Useless if there is no ally to attack the spotlighted foe
      next Battle::AI::MOVE_USELESS_SCORE if user.battler.allAllies.length == 0
    end
    # Generaly don't prefer this move, as it's a waste of the user's turn
    next score - 15
  }
)

#===============================================================================
#
#===============================================================================
# CannotBeRedirected

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("RandomlyDamageOrHealTarget",
  proc { |power, move, user, target, ai, battle|
    next 50   # Average power, ish
  }
)
Battle::AI::Handlers::MoveEffectScore.add("RandomlyDamageOrHealTarget",
  proc { |score, move, user, ai, battle|
    # Generaly don't prefer this move, as it may heal the target instead
    next score - 8
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("HealAllyOrDamageFoe",
  proc { |move, user, target, ai, battle|
    next !target.opposes?(user) && target.battler.canHeal?
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("HealAllyOrDamageFoe",
  proc { |score, move, user, target, ai, battle|
    if !target.opposes?(user)
      # Consider how much HP will be restored
      if target.hp >= target.totalhp * 0.5
        score -= 10
      else
        score += 20 * (target.totalhp - target.hp) / target.totalhp
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("CurseTargetOrLowerUserSpd1RaiseUserAtkDef1",
  proc { |move, user, ai, battle|
    next false if user.has_type?(:GHOST)
    will_fail = true
    (move.move.statUp.length / 2).times do |i|
      next if !user.battler.pbCanRaiseStatStage?(move.move.statUp[i * 2], user.battler, move.move)
      will_fail = false
      break
    end
    (move.move.statDown.length / 2).times do |i|
      next if !user.battler.pbCanLowerStatStage?(move.move.statDown[i * 2], user.battler, move.move)
      will_fail = false
      break
    end
    next will_fail
  }
)
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("CurseTargetOrLowerUserSpd1RaiseUserAtkDef1",
  proc { |move, user, target, ai, battle|
    next false if !user.has_type?(:GHOST)
    next true if target.effects[PBEffects::Curse] || !target.battler.takesIndirectDamage?
    next false
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CurseTargetOrLowerUserSpd1RaiseUserAtkDef1",
  proc { |score, move, user, ai, battle|
    next score if user.has_type?(:GHOST)
    score = ai.get_score_for_target_stat_raise(score, user, move.move.statUp)
    next score if score == Battle::AI::MOVE_USELESS_SCORE
    next ai.get_score_for_target_stat_drop(score, user, move.move.statDown, false)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("CurseTargetOrLowerUserSpd1RaiseUserAtkDef1",
  proc { |score, move, user, target, ai, battle|
    next score if !user.has_type?(:GHOST)
    # Don't prefer if user will faint because of using this move
    next Battle::AI::MOVE_USELESS_SCORE if user.hp <= user.totalhp / 2
    # Prefer early on
    score += 10 if user.turnCount < 2
    if ai.trainer.medium_skill?
      # Prefer if the user has no damaging moves
      score += 20 if !user.check_for_move { |m| m.damagingMove? }
      # Prefer if the target can't switch out to remove its curse
      score += 10 if !battle.pbCanChooseNonActive?(target.index)
    end
    if ai.trainer.high_skill?
      # Prefer if user can stall while damage is dealt
      if user.check_for_move { |m| m.is_a?(Battle::Move::ProtectMove) }
        score += 8
      end
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("EffectDependsOnEnvironment",
  proc { |score, move, user, target, ai, battle|
    # Determine this move's effect
    move.move.pbOnStartUse(user.battler, [target.battler])
    function_code = nil
    case move.move.secretPower
    when 2
      function_code = "SleepTarget"
    when 10
      function_code = "BurnTarget"
    when 0, 1
      function_code = "ParalyzeTarget"
    when 9
      function_code = "FreezeTarget"
    when 5
      function_code = "LowerTargetAttack1"
    when 14
      function_code = "LowerTargetDefense1"
    when 3
      function_code = "LowerTargetSpAtk1"
    when 4, 6, 12
      function_code = "LowerTargetSpeed1"
    when 8
      function_code = "LowerTargetAccuracy1"
    when 7, 11, 13
      function_code = "FlinchTarget"
    end
    if function_code
      next Battle::AI::Handlers.apply_move_effect_against_target_score(function_code,
         score, move, user, target, ai, battle)
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("HitsAllFoesAndPowersUpInPsychicTerrain",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("TargetNextFireMoveDamagesTarget",
  proc { |move, user, target, ai, battle|
    next target.effects[PBEffects::Powder]
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("TargetNextFireMoveDamagesTarget",
  proc { |score, move, user, target, ai, battle|
    # Effect wears off at the end of the round
    next Battle::AI::MOVE_USELESS_SCORE if target.faster_than?(user)
    # Prefer if target knows any Fire moves (moreso if that's the only type they know)
    if target.check_for_move { |m| m.pbCalcType(b.battler) == :FIRE }
      score += 10
      score += 10 if !target.check_for_move { |m| m.pbCalcType(b.battler) != :FIRE }
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("DoublePowerAfterFusionFlare",
  proc { |score, move, user, ai, battle|
    # Prefer if an ally knows Fusion Flare
    ai.each_ally(user.index) do |b, i|
      score += 10 if b.has_move_with_function?("DoublePowerAfterFusionBolt")
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("DoublePowerAfterFusionBolt",
  proc { |score, move, user, ai, battle|
    # Prefer if an ally knows Fusion Bolt
    ai.each_ally(user.index) do |b, i|
      score += 10 if b.has_move_with_function?("DoublePowerAfterFusionFlare")
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("PowerUpAllyMove",
  proc { |move, user, target, ai, battle|
    next target.effects[PBEffects::HelpingHand]
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("PowerUpAllyMove",
  proc { |score, move, user, target, ai, battle|
    next Battle::AI::MOVE_USELESS_SCORE if !target.check_for_move { |m| m.damagingMove? }
    next score + 4
  }
)

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("CounterPhysicalDamage",
  proc { |power, move, user, target, ai, battle|
    next 60   # Representative value
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CounterPhysicalDamage",
  proc { |score, move, user, ai, battle|
#    next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::HyperBeam] > 0
    attack = user.rough_stat(:ATTACK)
    spatk  = user.rough_stat(:SPECIAL_ATTACK)
    if attack * 1.5 < spatk
      score -= 60
#    elsif ai.trainer.medium_skill? && target.battler.lastMoveUsed
#      moveData = GameData::Move.get(target.battler.lastMoveUsed)
#      score += 60 if moveData.physical?
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("CounterSpecialDamage",
  proc { |power, move, user, target, ai, battle|
    next 60   # Representative value
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CounterSpecialDamage",
  proc { |score, move, user, ai, battle|
#    next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::HyperBeam] > 0
    attack = user.rough_stat(:ATTACK)
    spatk  = user.rough_stat(:SPECIAL_ATTACK)
    if attack > spatk * 1.5
      score -= 60
#    elsif ai.trainer.medium_skill? && target.battler.lastMoveUsed
#      moveData = GameData::Move.get(target.battler.lastMoveUsed)
#      score += 60 if moveData.special?
    end
    next score
  }
)

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("CounterDamagePlusHalf",
  proc { |power, move, user, target, ai, battle|
    next 60   # Representative value
  }
)
Battle::AI::Handlers::MoveEffectScore.add("CounterDamagePlusHalf",
  proc { |score, move, user, ai, battle|
#    next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::HyperBeam] > 0
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UserAddStockpileRaiseDefSpDef1",
  proc { |move, user, ai, battle|
    next user.effects[PBEffects::Stockpile] >= 3
  }
)
Battle::AI::Handlers::MoveEffectScore.add("UserAddStockpileRaiseDefSpDef1",
  proc { |score, move, user, ai, battle|
    score = ai.get_score_for_target_stat_raise(score, user, [:DEFENSE, 1, :SPECIAL_DEFENSE, 1], false)
    # More preferable if user also has Spit Up/Swallow
    if user.battler.pbHasMoveFunction?("PowerDependsOnUserStockpile",
                                       "HealUserDependingOnUserStockpile")
      score += [10, 8, 5, 3][user.effects[PBEffects::Stockpile]]
    end
    next score
  }
)

#===============================================================================
# NOTE: Don't worry about the stat drops caused by losing the stockpile, because
#       if these moves are known, they want to be used.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("PowerDependsOnUserStockpile",
  proc { |move, user, ai, battle|
    next user.effects[PBEffects::Stockpile] == 0
  }
)
Battle::AI::Handlers::MoveBasePower.add("PowerDependsOnUserStockpile",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("PowerDependsOnUserStockpile",
  proc { |score, move, user, ai, battle|
    # Slightly prefer to hold out for another Stockpile to make this move stronger
    score -= 5 if user.effects[PBEffects::Stockpile] < 2
    next score
  }
)

#===============================================================================
# NOTE: Don't worry about the stat drops caused by losing the stockpile, because
#       if these moves are known, they want to be used.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("HealUserDependingOnUserStockpile",
  proc { |move, user, ai, battle|
    next true if user.effects[PBEffects::Stockpile] == 0
    next true if !user.battler.canHeal? &&
                 user.effects[PBEffects::StockpileDef] == 0 &&
                 user.effects[PBEffects::StockpileSpDef] == 0
    next false
  }
)
Battle::AI::Handlers::MoveEffectScore.add("HealUserDependingOnUserStockpile",
  proc { |score, move, user, ai, battle|
    next Battle::AI::MOVE_USELESS_SCORE if !user.battler.canHeal?
    # Consider how much HP will be restored
    if user.hp >= user.totalhp * 0.5
      score -= 10
    else
      # Slightly prefer to hold out for another Stockpile to make this move stronger
      score -= 5 if user.effects[PBEffects::Stockpile] < 2
      score += 20 * (user.totalhp - user.hp) / user.totalhp
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("GrassPledge",
  proc { |score, move, user, ai, battle|
    # Prefer if an ally knows a different Pledge move
    ai.each_ally(user.index) do |b, i|
      score += 10 if b.has_move_with_function?("FirePledge", "WaterPledge")
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("FirePledge",
  proc { |score, move, user, ai, battle|
    # Prefer if an ally knows a different Pledge move
    ai.each_ally(user.index) do |b, i|
      score += 10 if b.has_move_with_function?("GrassPledge", "WaterPledge")
    end
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("WaterPledge",
  proc { |score, move, user, ai, battle|
    # Prefer if an ally knows a different Pledge move
    ai.each_ally(user.index) do |b, i|
      score += 10 if b.has_move_with_function?("GrassPledge", "FirePledge")
    end
    next score
  }
)

#===============================================================================
# NOTE: The move that this move will become is determined in def
#       set_up_move_check, and the score for that move is calculated instead. If
#       this move cannot become another move and will fail, the score for this
#       move is calculated as normal (and the code below says it fails).
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UseLastMoveUsed",
  proc { |move, user, ai, battle|
    next true if !battle.lastMoveUsed
    next move.move.moveBlacklist.include?(GameData::Move.get(battle.lastMoveUsed).function_code)
  }
)

#===============================================================================
# NOTE: The move that this move will become is determined in def
#       set_up_move_check, and the score for that move is calculated instead. If
#       this move cannot become another move and will fail, the score for this
#       move is calculated as normal (and the code below says it fails).
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("UseLastMoveUsedByTarget",
  proc { |move, user, target, ai, battle|
    next true if !target.battler.lastRegularMoveUsed
    next GameData::Move.get(target.battler.lastRegularMoveUsed).flags.none? { |f| f[/^CanMirrorMove$/i] }
  }
)

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
# UseMoveTargetIsAboutToUse

#===============================================================================
# NOTE: The move that this move will become is determined in def
#       set_up_move_check, and the score for that move is calculated instead.
#===============================================================================
# UseMoveDependingOnEnvironment

#===============================================================================
#
#===============================================================================
# UseRandomMove

#===============================================================================
# TODO: Review score modifiers.
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UseRandomMoveFromUserParty",
  proc { |move, user, ai, battle|
    will_fail = true
    battle.pbParty(user.index).each_with_index do |pkmn, i|
      next if !pkmn || i == user.party_index
      next if Settings::MECHANICS_GENERATION >= 6 && pkmn.egg?
      pkmn.moves.each do |pkmn_move|
        next if move.move.moveBlacklist.include?(pkmn_move.function_code)
        next if pkmn_move.type == :SHADOW
        will_fail = false
        break
      end
      break if !will_fail
    end
    next will_fail
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UseRandomUserMoveIfAsleep",
  proc { |move, user, ai, battle|
    will_fail = true
    user.battler.eachMoveWithIndex do |m, i|
      next if move.move.moveBlacklist.include?(m.function)
      next if !battle.pbCanChooseMove?(user.index, i, false, true)
      will_fail = false
      break
    end
    next will_fail
  }
)

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
# BounceBackProblemCausingStatusMoves

#===============================================================================
# TODO: Review score modifiers.
# TODO: This code shouldn't make use of target.
#===============================================================================
# StealAndUseBeneficialStatusMove

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("ReplaceMoveThisBattleWithTargetLastMoveUsed",
  proc { |move, user, ai, battle|
    next user.effects[PBEffects::Transform] || !user.battler.pbHasMove?(move.id)
  }
)
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("ReplaceMoveThisBattleWithTargetLastMoveUsed",
  proc { |move, user, target, ai, battle|
    next false if !user.faster_than?(target)
    last_move_data = GameData::Move.try_get(target.battler.lastRegularMoveUsed)
    next true if !last_move_data ||
                 user.battler.pbHasMove?(target.battler.lastRegularMoveUsed) ||
                 move.move.moveBlacklist.include?(last_move_data.function_code) ||
                 last_move_data.type == :SHADOW
    next false
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("ReplaceMoveThisBattleWithTargetLastMoveUsed",
  proc { |score, move, user, target, ai, battle|
    # Generally don't prefer, as this wastes the user's turn just to gain a move
    # of unknown utility
    score -= 8
    # Slightly prefer if this move will definitely succeed, just for the sake of
    # getting rid of this move
    score += 5 if user.faster_than?(target)
    next score
  }
)

#===============================================================================
#
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("ReplaceMoveThisBattleWithTargetLastMoveUsed",
                                                         "ReplaceMoveWithTargetLastMoveUsed")
Battle::AI::Handlers::MoveEffectScore.copy("ReplaceMoveThisBattleWithTargetLastMoveUsed",
                                           "ReplaceMoveWithTargetLastMoveUsed")
