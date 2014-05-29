class VMListPane extends Pane

  constructor: (options = {}, data) ->

    options.cssClass = KD.utils.curry 'vm-list-pane', options.cssClass

    super options, data

    @fetchVMs()

  fetchVMs: ->
    {vmController, kontrol} = KD.singletons
    vmController.fetchVMs (err, vms) =>
      if err
        ErrorLog.create "terminal: Couldn't fetch vms", reason: err
        return new KDNotificationView
          title : "Couldn't fetch your VMs"
          type  : 'mini'

      vms.sort (a,b) ->
        return a.hostnameAlias > b.hostnameAlias

      for vm in vms
        @addSubView new VMPaneListItem {}, vm

      @addBuyVMButton()

  addBuyVMButton: ->
    buyVMButton  = new KDCustomHTMLView
      tagName    : 'a'
      cssClass   : 'buy-vm-button'
      partial    : '<span class="icon"></span>Buy another VM'
      attributes :
        href     : '/Pricing'

    @addSubView buyVMButton


class VMPaneListItem extends JView

  constructor: (options = {}, data) ->

    options.cssClass = KD.utils.curry 'vm-item', options.cssClass

    super options, data

    @unsetClass 'kdview'

    @createElements()

  createElements: ->
    appManager     = KD.getSingleton 'appManager'
    data           = @getData()

    @domainName    = new KDCustomHTMLView
      tagName      : 'span'
      cssClass     : 'domain-name'
      partial      : data.hostnameAlias.replace 'koding.kd.io', 'kd.io'

    @actionsButton = new KDButtonViewWithMenu
      title        : ""
      icon         : yes
      delegate     : this
      cssClass     : 'actions'
      iconClass    : 'icon'
      cssClass     : 'actions-menu'
      style        : 'resurrection'
      menu         : @getMenuItems()

  getMenuItems: ->
    data                  = @getData()
    appManager            = KD.getSingleton 'appManager'
    menuItems             =
      "Open VM terminal"  : callback: => appManager.tell 'IDE', 'openVMTerminal', data
      "Open VM domain"    : callback: => appManager.tell 'IDE', 'openVMWebPage',  data
      "Mount to filetree" : callback: => appManager.tell 'IDE', 'mountVM',        data

    return menuItems

  pistachio: ->
    """
      {{> @domainName}}
      {{> @actionsButton}}
    """
