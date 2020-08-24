local unitTypes = require("scripts/unit/unitTypesList.nut")

global const UNIT_WEAPONS_ZERO    = 0
global const UNIT_WEAPONS_WARNING = 1
global const UNIT_WEAPONS_READY   = 2
const KGF_TO_NEWTON = 9.807

local weaponsStatusNameByStatusCode = {
  [UNIT_WEAPONS_ZERO]    = "zero",
  [UNIT_WEAPONS_WARNING] = "warning",
  [UNIT_WEAPONS_READY]   = "ready"
}

local TRIGGER_TYPE = {
  MACHINE_GUN = "machine gun"
  CANNON      = "cannon"
  ADD_GUN     = "additional gun"
  TURRETS     = "turrets"
  SMOKE       = "smoke"
  FLARES      = "flares"
  BOMBS       = "bombs"
  TORPEDOES   = "torpedoes"
  ROCKETS     = "rockets"
  AAM         = "aam"
  AGM         = "agm"
  ATGM        = "atgm"
}

local WEAPON_TYPE = {
  GUNS        = "guns"
  CANNONS     = "cannons"
  TURRETS     = "turrets"
  SMOKE       = "smoke"
  FLARES      = "flares"    // Flares (countermeasure)
  BOMBS       = "bombs"
  TORPEDOES   = "torpedoes"
  ROCKETS     = "rockets"   // Rockets
  AAM         = "aam"       // Air-to-Air Missiles
  AGM         = "agm"       // Air-to-Ground Missile, Anti-Tank Guided Missiles
}

local CONSUMABLE_TYPES = [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM, WEAPON_TYPE.ROCKETS,
  WEAPON_TYPE.TORPEDOES, WEAPON_TYPE.BOMBS, WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES ]

local WEAPON_TAG = {
  ADD_GUN          = "additionalGuns"
  BULLET           = "bullet"
  ROCKET           = "rocket"
  BOMB             = "bomb"
  TORPEDO          = "torpedo"
  FRONT_GUN        = "frontGun"
  CANNON           = "cannon"
  ANTI_SHIP        = "antiShip"
  ANTI_SHIP_BOMB   = "antiShipBomb"
  ANTI_SHIP_ROCKET = "antiShipRocket"
  ANTI_TANK_BOMB   = "antiTankBomb"
  ANTI_TANK_ROCKET = "antiTankRocket"
  ANTI_HEAVY_TANK  = "antiHeavyTanks"
}

local WEAPON_TEXT_PARAMS = { //const
  isPrimary             = null //bool or null. When null return descripton for all weaponry.
  weaponPreset          = -1 //int weaponIndex or string weapon name
  newLine               ="\n" //weapons delimeter
  detail                = INFO_DETAIL.FULL
  needTextWhenNoWeapons = true
  ediff                 = null //int. when not set, uses get_current_ediff() function
  isLocalState          = true //should apply my local parameters to unit (modifications, crew skills, etc)
  weaponsFilterFunc     = null //function. When set, only filtered weapons are collected from weaponPreset.
}

local function getLastWeapon(unitName)
{
  local res = ::get_last_weapon(unitName)
  if (res != "")
    return res

  //validate last_weapon value
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return res
  foreach(weapon in unit.weapons)
    if (::is_weapon_visible(unit, weapon)
        && ::is_weapon_enabled(unit, weapon))
    {
      ::set_last_weapon(unitName, weapon.name)
      return weapon.name
    }
  return res
}

local function setLastWeapon(unitName, weaponName)
{
  if (weaponName == getLastWeapon(unitName))
    return

  ::set_last_weapon(unitName, weaponName)
  ::broadcastEvent("UnitWeaponChanged", { unitName = unitName, weaponName = weaponName })
}

local function addWeaponsFromBlk(weapons, block, unit, weaponsFilterFunc = null, wConf = null)
{
  local unitType = ::get_es_unit_type(unit)

  foreach (weapon in (block % "Weapon"))
  {
    if (weapon?.dummy)
      continue

    if (!weapon?.blk)
      continue

    local weaponBlk = ::DataBlock( weapon.blk )
    if (!weaponBlk)
      continue

    if (weaponsFilterFunc?(weapon.blk, weaponBlk) == false)
      continue

    local currentTypeName = WEAPON_TYPE.TURRETS
    local weaponTag = WEAPON_TAG.BULLET

    if (weaponBlk?.rocketGun)
    {
      currentTypeName = ""
      if (weapon?.trigger)
        if (weapon.trigger == TRIGGER_TYPE.AGM || weapon.trigger == TRIGGER_TYPE.ATGM)
          currentTypeName = WEAPON_TYPE.AGM
        else if (weapon.trigger == TRIGGER_TYPE.AAM)
          currentTypeName = WEAPON_TYPE.AAM
        else if (weapon.trigger == TRIGGER_TYPE.FLARES)
          currentTypeName = WEAPON_TYPE.FLARES
        else
          currentTypeName = WEAPON_TYPE.ROCKETS

      if (weapon?.triggerGroup == "smoke")
        currentTypeName = WEAPON_TYPE.SMOKE
      weaponTag = WEAPON_TAG.ROCKET
    }
    else if (weaponBlk?.bombGun)
    {
      currentTypeName = WEAPON_TYPE.BOMBS
      weaponTag = WEAPON_TAG.BOMB
    }
    else if (weaponBlk?.torpedoGun)
    {
      currentTypeName = WEAPON_TYPE.TORPEDOES
      weaponTag = WEAPON_TAG.TORPEDO
    }
    else if (unitType == ::ES_UNIT_TYPE_TANK ||
      ::isInArray(weapon.trigger, [ TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON,
        TRIGGER_TYPE.ADD_GUN, TRIGGER_TYPE.ROCKETS, TRIGGER_TYPE.AGM, TRIGGER_TYPE.AAM,
        TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.TORPEDOES, TRIGGER_TYPE.SMOKE, TRIGGER_TYPE.FLARES ]))
    { //not a turret
      currentTypeName = WEAPON_TYPE.GUNS
      if (weaponBlk?.bullet && typeof(weaponBlk?.bullet) == "instance"
          && ::isCaliberCannon(1000 * ::getTblValue("caliber", weaponBlk?.bullet, 0)))
        currentTypeName = WEAPON_TYPE.CANNONS
    }
    else if (weaponBlk?.fuelTankGun || weaponBlk?.boosterGun || weaponBlk?.airDropGun || weaponBlk?.undercarriageGun)
      continue

    local isTurret = currentTypeName == WEAPON_TYPE.TURRETS

    local bullets = weapon?.bullets ?? 0
    if (bullets <= 0)
      bullets = ::max(weaponBlk?.bullets, 0)

    local item = {
      turret = null
      ammo = 0
      num = 0
      caliber = 0
      massKg = 0
      massLbs = 0
      explosiveType = null
      explosiveMass = 0
      dropSpeedRange = null
      dropHeightRange = null
      iconType = null
      amountPerTier = null
      isGun = null
      bulletType = null
      tiers = {}
      blk = null
    }

    if (wConf)
      foreach (wc in (wConf % "Weapon"))
        if (weapon.blk.tolower() == wc.blk.tolower())
        {
          item.iconType <- wc?.iconType
          item.amountPerTier <- wc?.amountPerTier
          foreach (t in (wc % "tier"))
            item.tiers[t.idx] <- {amountPerTier = t?.amountPerTier, iconType = t?.iconType}
          break
        }


    local needBulletParams = !::isInArray(currentTypeName, [WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES])

    if (needBulletParams && weaponTag.len() && weaponBlk?[weaponTag])
    {
      local itemBlk = weaponBlk[weaponTag]
      local isGun = ::isInArray(currentTypeName, [WEAPON_TYPE.GUNS, WEAPON_TYPE.CANNONS])
      item.isGun = isGun
      item.caliber = itemBlk?.caliber ?? item.caliber
      item.massKg = itemBlk?.mass ?? item.massKg
      item.massLbs = itemBlk?.mass_lbs ?? item.massLbs
      item.explosiveType = itemBlk?.explosiveType ?? item.explosiveType
      item.explosiveMass = itemBlk?.explosiveMass ?? item.explosiveMass
      item.iconType = isGun ? weaponBlk?.iconType : item.iconType ?? itemBlk?.iconType
      item.amountPerTier = isGun ? weaponBlk?.amountPerTier
        : item.amountPerTier ?? itemBlk?.amountPerTier
      item.bulletType = itemBlk?.bulletType
      item.blk = weapon.blk

      if (::isInArray(currentTypeName, [ WEAPON_TYPE.ROCKETS, WEAPON_TYPE.AGM, WEAPON_TYPE.AAM ]))
      {
        item.machMax  <- itemBlk?.machMax ?? 0
        item.maxSpeed <- (itemBlk?.maxSpeed ?? 0) || (itemBlk?.endSpeed ?? 0)

        if (currentTypeName == WEAPON_TYPE.AAM || currentTypeName == WEAPON_TYPE.AGM)
        {
          if (itemBlk?.operated == true)
          {
            item.autoAiming <- itemBlk?.autoAiming ?? false
            item.isBeamRider <- itemBlk?.isBeamRider ?? false
          }
          else
            item.guidanceType <- itemBlk?.guidanceType

          if ((itemBlk?.rangeMax ?? 0) != 0)
            item.launchRange <- itemBlk.rangeMax

          if (itemBlk?.irSeeker != null)
          {
            local rangeRearAspect = itemBlk.irSeeker?.rangeBand0 ?? 0
            local rangeAllAspect  = itemBlk.irSeeker?.rangeBand1 ?? 0
            if (currentTypeName == WEAPON_TYPE.AAM)
            {
              item.seekerRangeRearAspect <- rangeRearAspect
              item.seekerRangeAllAspect  <- rangeAllAspect
              if (rangeRearAspect > 0 || rangeAllAspect > 0)
                item.allAspect <- rangeAllAspect * 1.0 >= 0.2 * rangeRearAspect
            }
            else if (currentTypeName == WEAPON_TYPE.AGM && (itemBlk.irSeeker?.groundVehiclesAsTarget ?? false))
            {
              if (rangeRearAspect > 0 || rangeAllAspect > 0)
                item.seekerRange <- ::min(rangeRearAspect, rangeAllAspect)
            }
            if (itemBlk?.guidanceType == "ir" && (itemBlk.irSeeker?.bandMaskToReject ?? 0) != 0)
              item.seekerECCM <- true
          }
        }
        if (currentTypeName == WEAPON_TYPE.AAM)
        {
          item.loadFactorMax <- itemBlk?.loadFactorMax ?? 0
        }
        else if (currentTypeName == WEAPON_TYPE.AGM)
        {
          item.operatedDist <- itemBlk?.operatedDist ?? 0
        }
      }
      else  if (currentTypeName == WEAPON_TYPE.TORPEDOES)
      {
        item.dropSpeedRange = itemBlk.getPoint2("dropSpeedRange", Point2(0,0))
        if (item.dropSpeedRange.x == 0 && item.dropSpeedRange.y == 0)
          item.dropSpeedRange = null
        item.dropHeightRange = itemBlk.getPoint2("dropHeightRange", Point2(0,0))
        if (item.dropHeightRange.x == 0 && item.dropHeightRange.y == 0)
          item.dropHeightRange = null
        item.maxSpeedInWater <- itemBlk?.maxSpeedInWater ?? 0
        item.distToLive <- itemBlk?.distToLive ?? 0
        item.diveDepth <- itemBlk?.diveDepth ?? 0
        item.armDistance <- itemBlk?.armDistance ?? 0
      }
    }

    if(isTurret && weapon.turret)
    {
      local turretInfo = weapon.turret
      item.turret = ::u.isDataBlock(turretInfo) ? turretInfo.head : turretInfo
    }

    if (!(currentTypeName in weapons))
      weapons[ currentTypeName ] <- []

    local weaponName = ::get_weapon_name_by_blk_path(weapon.blk)
    local trIdx = -1
    foreach(idx, t in weapons[currentTypeName])
      if (weapon.trigger == t.trigger ||
          ((weaponName in t) && ::is_weapon_params_equal(item, t[weaponName])))
      {
        trIdx = idx
        break
      }

    // Merging duplicating weapons with different weaponName
    // (except guns, because there exists different guns with equal params)
    if (trIdx >= 0 && !(weaponName in weapons[currentTypeName][trIdx]) && weaponTag != WEAPON_TAG.BULLET)
      foreach (name, existingItem in weapons[currentTypeName][trIdx])
        if (::is_weapon_params_equal(item, existingItem))
        {
          weaponName = name
          break
        }

    if (trIdx < 0)
    {
      weapons[currentTypeName].append({ trigger = weapon.trigger, caliber = 0 })
      trIdx = weapons[currentTypeName].len() - 1
    }

    local currentType = weapons[currentTypeName][trIdx]

    if (!(weaponName in currentType))
    {
      currentType[weaponName] <- item
      if (item.caliber > currentType.caliber)
        currentType.caliber = item.caliber
    }
    currentType[weaponName].ammo += bullets
    currentType[weaponName].num += 1
  }

  return weapons
}

//weapon - is a weaponData gathered by addWeaponsFromBlk
local function getWeaponExtendedInfo(weapon, weaponType, unit, ediff, newLine)
{
  local res = []
  local colon = ::loc("ui/colon")

  local massText = null
  if (weapon.massLbs > 0)
    massText = format(::loc("mass/lbs"), weapon.massLbs)
  else if (weapon.massKg > 0)
    massText = format(::loc("mass/kg"), weapon.massKg)
  if (massText)
    res.append("".concat(::loc("shop/tank_mass"), " ", massText))

  if (::isInArray(weaponType, [ "rockets", "agm", "aam" ]))
  {
    if (weapon?.guidanceType != null || weapon?.autoAiming != null)
    {
      local aimingType = weapon?.autoAiming == null ? ""
        : weapon.autoAiming && weapon.isBeamRider ? "beamRiding"
        : weapon.autoAiming ? "semiautomatic"
        : "manual"
      local guidanceTxt = aimingType != ""
        ? ::loc($"missile/aiming/{aimingType}")
        : ::loc($"missile/guidance/{weapon.guidanceType}")
      res.append("".concat(::loc("missile/guidance"), colon, guidanceTxt))
    }
    if (weapon?.allAspect != null)
      res.append("".concat(::loc("missile/aspect"), colon,
        ::loc("missile/aspect/{0}".subst(weapon.allAspect ? "allAspect" : "rearAspect"))))
    if (weapon?.seekerRangeRearAspect)
      res.append("".concat(::loc("missile/seekerRange/rearAspect"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeRearAspect)))
    if (weapon?.seekerRangeAllAspect)
      res.append("".concat(::loc("missile/seekerRange/allAspect"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeAllAspect)))
    if (weapon?.seekerRange)
      res.append("".concat(::loc("missile/seekerRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRange)))
    if (weapon?.seekerECCM)
      res.append("".concat(::loc("missile/eccm"), colon, ::loc("options/yes")))
    if (weapon?.launchRange)
      res.append("".concat(::loc("missile/launchRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.launchRange)))
    if (weapon?.machMax)
      res.append("".concat(::loc("rocket/maxSpeed"), colon,
        ::format("%.1f %s", weapon.machMax, ::loc("measureUnits/machNumber"))))
    else if (weapon?.maxSpeed)
      res.append("".concat(::loc("rocket/maxSpeed"), colon,
        ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(weapon.maxSpeed)))
    if (weapon?.loadFactorMax)
      res.append("".concat(::loc("missile/loadFactorMax"), colon,
        ::g_measure_type.GFORCE.getMeasureUnitsText(weapon.loadFactorMax)))
    if (weapon?.operatedDist)
      res.append("".concat(::loc("firingRange"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.operatedDist)))
  }
  else if (weaponType == "torpedoes")
  {
    local torpedoMod = "torpedoes_movement_mode"
    if (::shop_is_modification_enabled(unit.name, torpedoMod))
    {
      local mod = ::getModificationByName(unit, torpedoMod)
      local diffId = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff()).crewSkillName
      local effects = mod?.effects?[diffId]
      if (effects)
      {
        weapon = clone weapon
        foreach (k, v in weapon)
        {
          local kEffect = $"{k}Torpedo"
          if ((kEffect in effects) && type(v) == type(effects[kEffect]))
            weapon[k] += effects[kEffect]
        }
      }
    }

    if (weapon?.maxSpeedInWater)
      res.append("".concat(::loc("torpedo/maxSpeedInWater"), colon,
        ::g_measure_type.SPEED.getMeasureUnitsText(weapon?.maxSpeedInWater)))

    if (weapon?.distToLive)
      res.append("".concat(::loc("torpedo/distanceToLive"), colon,
        ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon?.distToLive)))

    if (weapon?.diveDepth)
      res.append("".concat(::loc("bullet_properties/diveDepth"), colon,
        ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.diveDepth)))

    if (weapon?.armDistance)
      res.append("".concat(::loc("torpedo/armingDistance"), colon,
        ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.armDistance)))
  }

  if (weapon.explosiveType != null)
  {
    res.append("".concat(::loc("bullet_properties/explosiveType"), colon,
      ::loc($"explosiveType/{weapon.explosiveType}")))
    if (weapon.explosiveMass)
    {
      local measureType = ::g_measure_type.getTypeByName("kg", true)
      res.append("".concat(::loc("bullet_properties/explosiveMass"), colon,
        measureType.getMeasureUnitsText(weapon.explosiveMass)))
    }
    if (weapon.explosiveMass)
    {
      local tntEqText = ::g_dmg_model.getTntEquivalentText(weapon.explosiveType, weapon.explosiveMass)
      if (tntEqText.len())
        res.append("".concat(::loc("bullet_properties/explosiveMassInTNTEquivalent"), colon, tntEqText))
    }

    if (weaponType == "bombs" && unit.unitType != unitTypes.SHIP)
    {
      local destrTexts = ::g_dmg_model.getDestructionInfoTexts(weapon.explosiveType, weapon.explosiveMass, weapon.massKg)
      foreach (key in ["maxArmorPenetration", "destroyRadiusArmored", "destroyRadiusNotArmored"])
      {
        local valueText = destrTexts[$"{key}Text"]
        if (valueText.len())
          res.append("".concat(::loc($"bombProperties/{key}"), colon, valueText))
      }
    }
  }

  return "".concat(res.len() ? newLine : "", newLine.join(res))
}

local function getUnitWeaponry(unit, p = WEAPON_TEXT_PARAMS)
{
  if (!unit)
    return null

  local unitBlk = ::get_full_unit_blk(unit.name)
  if( !unitBlk )
    return null

  local weapons = {}
  p = WEAPON_TEXT_PARAMS.__merge(p)
  local primaryMod = ""
  local weaponPresetIdx = -1
  if ((typeof(p.weaponPreset) == "string") || p.weaponPreset < 0)
  {
    if (!p.isPrimary)
    {
      local curWeap = (typeof(p.weaponPreset) == "string") ? p.weaponPreset : getLastWeapon(unit.name)
      foreach(idx, w in unit.weapons)
        if (w.name == curWeap || (weaponPresetIdx < 0 && !::isWeaponAux(w)))
          weaponPresetIdx = idx
      if (weaponPresetIdx < 0)
        return weapons
    }
    if (p.isPrimary && typeof(p.weaponPreset)=="string")
      primaryMod = p.weaponPreset
    else
      primaryMod = ::get_last_primary_weapon(unit)
  } else
    weaponPresetIdx = p.weaponPreset

  if (p.isPrimary || p.isPrimary==null)
  {
    local primaryBlk = ::getCommonWeaponsBlk(unitBlk, primaryMod)
    if (primaryBlk)
      weapons = addWeaponsFromBlk({}, primaryBlk, unit, p.weaponsFilterFunc)
  }

  if (unitBlk?.weapon_presets != null && !p.isPrimary)
  {
    local wpBlk = null
    local wConf = null
    foreach (wp in (unitBlk.weapon_presets % "preset"))
    {
      if (wp.name == unit.weapons?[weaponPresetIdx]?.name)
      {
        wpBlk = ::DataBlock(wp.blk)
        wConf = wp?.weaponConfig
        if (wConf?.presetType != null)
            unit.weapons[weaponPresetIdx].presetType <- wConf.presetType
        break
      }
    }

    if (!wpBlk)
      return weapons
    weapons = addWeaponsFromBlk(weapons, wpBlk, unit, p.weaponsFilterFunc, wConf)
  }

  return weapons
}

local function getSecondaryWeaponsList(unit)
{
  local weaponsList = []
  local unitName = unit.name
  local lastWeapon = ::get_last_weapon(unitName)
  foreach(weapon in unit.weapons)
  {
    if(::isWeaponAux(weapon))
      continue

    weaponsList.append(weapon)
    if(lastWeapon=="" && ::shop_is_weapon_purchased(unitName, weapon.name))
      setLastWeapon(unitName, weapon.name)
  }

  return weaponsList
}

local function getPresetsList(unit, chooseMenuList)
{
  if (!chooseMenuList)
    return getSecondaryWeaponsList(unit)

  local weaponsList = []
  foreach (item in chooseMenuList)
    weaponsList.append(item.weaponryItem.__merge({isEnabled = item.enabled}))
  return weaponsList
}

local getWeaponsStatusName = @(weaponsStatus) weaponsStatusNameByStatusCode[weaponsStatus]

return {
  KGF_TO_NEWTON           = KGF_TO_NEWTON
  TRIGGER_TYPE            = TRIGGER_TYPE
  WEAPON_TYPE             = WEAPON_TYPE
  WEAPON_TAG              = WEAPON_TAG
  CONSUMABLE_TYPES        = CONSUMABLE_TYPES
  WEAPON_TEXT_PARAMS      = WEAPON_TEXT_PARAMS
  getLastWeapon           = getLastWeapon
  setLastWeapon           = setLastWeapon
  getSecondaryWeaponsList = getSecondaryWeaponsList
  getPresetsList          = getPresetsList
  addWeaponsFromBlk       = addWeaponsFromBlk
  getWeaponExtendedInfo   = getWeaponExtendedInfo
  getUnitWeaponry         = getUnitWeaponry
  getWeaponsStatusName    = getWeaponsStatusName
}