from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { notifyMailRead } = require("%scripts/matching/serviceNotifications/postbox.nut")
let { removeInviteToOperation } = require("%scripts/worldWar/wwInvites.nut")

const WW_OPERATION_INVITE_EXPIRE_SEC = 3600
let inviteActiveColor = "userlogColoredText"

::g_invites_classes.Operation <- class extends ::BaseInvite {
  mailId           = null
  operationId      = -1
  senderId         = ""
  country          = ""

  clanTag          = ""
  isStarted        = false

  isAccepted                 = false
  senderContact              = null
  needCheckSystemRestriction = true

  static function getUidByParams(p) {
    return $"OP_{p?.operationId ?? ""}"
  }


  isValid = @() !this.isAccepted && !this.isRejected

  getIcon = @() "#ui/gameuiskin#battles_open.png"

  function updateCustomParams(p, initial = false) {
    this.mailId = p?.mail_id
    this.senderId = p?.senderId ?? this.senderId
    this.country = p?.country ?? this.country
    this.operationId = p?.operationId ?? this.operationId
    this.isStarted = p?.isStarted ?? this.isStarted
    this.clanTag = p?.clanTag ?? this.clanTag

    this.updateInviterContact()

    this.setDelayed(true)
    let cb = Callback(function(_) {
        this.updateInviterContact()
        this.setDelayed(false)
      }, this)

    requestUsersInfo([this.senderId], cb, cb)

    this.isAccepted = false

    if (initial)
      this.setTimedParams(0, ::get_charserver_time_sec() + WW_OPERATION_INVITE_EXPIRE_SEC)
  }

  function updateInviterContact() {
    this.senderContact = ::getContact(this.senderId)
    this.updateInviterName()
  }

  function updateInviterName() {
    if (this.senderContact)
      this.inviterName = this.senderContact.getName()
  }

  function getInviteText() {
    let operationStr = colorize(inviteActiveColor, $"{loc("ui/number_sign")}{this.operationId}")
    if (this.clanTag != "")
      return loc(this.isStarted ? "worldWar/userlog/startOperation"
        : "worldWar/userlog/createOperation", {
          clan = colorize(inviteActiveColor, this.clanTag)
          operation = operationStr
        })
    return loc("worldwar/inviteOperation", {
      name = colorize(inviteActiveColor, this.getInviterName())
      operation = operationStr
    })
  }

  getPopupText = @() this.getInviteText()
  haveRestrictions = @() !::isInMenu()

  function getRestrictionText(){
    if (this.haveRestrictions())
      return loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function implAccept() {
    if (this.isOutdated()) {
      ::g_invites.showExpiredInvitePopup()
      return
    }

    let onSuccess = Callback(function() {
        this.isAccepted = true
        this.remove()
        removeInviteToOperation(this.operationId)
        if (this.mailId)
          notifyMailRead(this.mailId)
    }, this)
    let requestBlk = ::DataBlock()
    requestBlk.operationId = this.operationId
    actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null,
      @() ::g_world_war.joinOperationById(this.operationId, this.country, null, onSuccess))
  }

  function accept() {
    if (isShowGoldBalanceWarning())
      return

    let acceptCallback = Callback(this.implAccept, this)
    let callback = function () { ::queues.checkAndStart(acceptCallback, null, "isCanNewflight")}
    let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
      { isLeaderCanJoin = true, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (!canJoin)
      return

    callback()
  }

  function reject() {
    if (this.mailId)
      notifyMailRead(this.mailId)

    if (this.isOutdated())
      return this.remove()

    this.isRejected = true
    this.remove()
    removeInviteToOperation(this.operationId)
  }
}
