do ->

  loadWorkspace = (machineLabel, workspaceSlug, username, channelId) ->
    username or= KD.nick()
    workspace  = ws  for ws in KD.userWorkspaces when ws.slug is workspaceSlug
    machine    = getMachine machineLabel, username

    if workspace
      loadIDE { machine, workspace, username, channelId }

    else
      if workspaceSlug is 'my-workspace'
        workspace =
          isDummy      : yes
          isDefault    : yes
          slug         : 'my-workspace'
          machineLabel : machine?.slug or machine?.label

        loadIDE { machine, workspace, username, channelId }

      else
        routeToLatestWorkspace()


  selectWorkspaceOnSidebar = (data) ->
    mainView = KD.getSingleton 'mainView'
    mainView.activitySidebar.selectWorkspace data


  getMachine = (label, username) ->
    machine = null

    for m in KD.userMachines
      hasSameLabel = (m.label is label) or (m.slug is label)
      hasSameUser  = m.data.credential is username

      if hasSameLabel and hasSameUser
        machine = m

    return machine


  loadIDE = (data) ->

    { machine, workspace, username, channelId } = data

    appManager = KD.getSingleton 'appManager'
    ideApps    = appManager.appControllers.IDE
    machineUId = machine?.uid
    callback   = ->
      appManager.open 'IDE', { forceNew: yes }, (app) ->
        app.mountedMachineUId   = machineUId
        app.workspaceData       = workspace

        if username and username isnt KD.nick()
          app.isInSession       = yes
          app.amIHost           = no
          app.collaborationHost = username
          app.channelId         = channelId
        else
          app.amIHost           = yes

        appManager.tell 'IDE', 'mountMachineByMachineUId', machineUId
        selectWorkspaceOnSidebar data

    return callback()  unless ideApps?.instances

    for instance in ideApps.instances
      isSameMachine   = instance.mountedMachineUId is machineUId
      isSameWorkspace = instance.workspaceData is workspace

      if isSameMachine
        if isSameWorkspace then ideInstance = instance
        else if workspace.slug is 'my-workspace'
          if instance.workspaceData?.isDefault
            ideInstance = instance

    if ideInstance
      appManager.showInstance ideInstance
      selectWorkspaceOnSidebar data
    else
      callback()


  putVMInWorkspace = (machine)->
    localStorage    = KD.getSingleton("localStorageController").storage "IDE"
    latestWorkspace = localStorage.getValue 'LatestWorkspace'

    machineLabel    = machine?.slug or machine?.label or ''
    workspaceSlug   = 'my-workspace'

    if latestWorkspace
      for ws in KD.userWorkspaces when ws.slug is latestWorkspace.workspaceSlug
        {machineLabel, workspaceSlug} = latestWorkspace

    KD.getSingleton('router').handleRoute "/IDE/#{machineLabel}/#{workspaceSlug}"


  routeToLatestWorkspace = (options = {}) ->

    {params}       = options
    {machineLabel} = params  if params

    # we assume that if machineLabel is all numbers it is the channelId - SY
    return loadCollaborativeIDE machineLabel  if machineLabel and /^[0-9]+$/.test machineLabel

    machine = KD.userMachines.first
    return putVMInWorkspace machine  if machine

    KD.singletons.computeController.fetchMachines (err, machines)->

      if err or not machines.length
        KD.getSingleton('router').handleRoute "/IDE/koding-vm-0/my-workspace"
        return

      putVMInWorkspace machines.first


  loadCollaborativeIDE = (id) ->

    KD.singletons.socialapi.cacheable 'channel', id, (err, channel) ->

      return routeToLatestWorkspace() if err

      KD.remote.api.JWorkspace.fetchByMachines()

        .then (workspaces) ->

          KD.userWorkspaces = workspaces
          KD.singletons.mainView.activitySidebar.updateMachineTree()

          try
            workspaces.forEach (workspace) =>

              return  unless workspace.channelId is channel.id

              machine = (KD.userMachines.filter (m) -> m.uid is workspace.machineUId)[0]

              query  = socialApiId: channel.creatorId
              KD.remote.api.JAccount.some query, {}, (err, account) =>
                return throw new Error err  if err

                username  = account.first.profile.nickname
                channelId = channel.id
                return loadIDE { machine, workspace, username, channelId }

          catch e
            return routeToLatestWorkspace()

        .error (err) ->

          console.error err
          routeToLatestWorkspace()


  KD.registerRoutes 'IDE',

    '/:name?/IDE': routeToLatestWorkspace

    '/:name?/IDE/:machineLabel': routeToLatestWorkspace

    '/:name?/IDE/:machineLabel/:workspaceSlug': (data) ->

      { machineLabel, workspaceSlug } = data.params

      loadWorkspace machineLabel, workspaceSlug