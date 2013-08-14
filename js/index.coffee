class Player

  cards: []        # collection of cards
  isWinner: false  # player is winner in current turn
  isRun: false     # prevent multiple rung

  options: {}      # game options

  # initialize
  #
  # @private
  constructor: (@name) ->
    @$el = $("##{@name}-container")

  # move card to game collection
  #
  # @private
  moveCard: (cards, typeTurn)->
    @isRun = true
    @showMoveCard(typeTurn)
    card = @cards.pop()
    card['player'] = @name
    cards.push(card)
    @updateCount()

  # change count text
  #
  # @private
  updateCount: ->
    @$el.find('.count').text(@getCountCards())

  # return count of cards
  getCountCards: ->
    @cards.length

  packIsEmpty: ->
    @getCountCards() <= 1

  # show moving card to game
  #
  # @private
  showMoveCard: (typeTurn)->
    @changeShirt()
    if typeTurn is 'normal' then @showCard()

    $card = @$el.find('.card.active')
    $card.css({'z-index': 100})
    cardOffset = $card.offset()

    $dest = $(".#{@name}-field").find('.card')
    destOffset = $dest.offset()
    left = destOffset.left - cardOffset.left
    top  = cardOffset.top - destOffset.top

    self = @

    $card.animate({
      left: "+=#{left}",
      top: "-=#{top}"
    },
    {
      queue:    off,
      duration: self.getSpeed(),
      easing:   'backEaseInOut',
      complete: ->
        setTimeout(->
          $dest.attr('class', $card.attr('class'))
          self.clearCard()
          if self.isWinner
            self.showMoveCardBack()
          else
            self.isRun = false
            self.activateButton()
        self.options['speed'])
    })

  # show moving card back to player
  #
  # @private
  showMoveCardBack: ->
    destOffset = @$el.find('.card.active').offset()
    $cards = $('#game-container').find('.card')
    self = @

    $.map($cards, (el, i)->
      $card = $(el)
      $card.css({'z-index': 1})
      cardOffset = $card.offset()
      left = destOffset.left - cardOffset.left
      top  = cardOffset.top - destOffset.top

      $card.animate({
        left: "+=#{left}",
        top: "-=#{top}px"
      },
      {
        queue:false,
        duration: self.getBackSpeed(),
        easing:'linear',
        complete: ->
          self.clearCard()
          self.updateCount()
          self.changeShirt()
          $card.attr('class', 'card active card-empty')
          $card.css({top: 0, left: 0})
          self.isWinner = false
          self.isRun = false
      })
    )

  # show face of card
  #
  # @private
  showCard: ->
    if @cards.length isnt 0
      card = @cards.slice(-1)[0]
      cardClass = "card-#{card.type}-#{card.power}"
    else
      cardClass = "card-empty"
    @$el.find('.card.active').attr('class', "card active #{cardClass}")

  # change shirt of pack
  #
  # @private
  changeShirt: ->
    $card = @$el.find('.card.passive')
    if @packIsEmpty()
      $card.addClass('card-empty')
      $card.removeClass('card-shirt')
    else if $card.hasClass('card-shirt') is false
      $card.addClass('card-shirt')
      $card.removeClass('card-empty')

  getSpeed: ->
    @options['speed']

  getBackSpeed: ->
    speed = @options['speed']
    if speed > 200 then speed - 200 else speed

  # activate turn button
  #
  # @private
  activateButton: ->
    $('#turn-btn').removeClass('passive')

  # restore all cards css to default
  reset: ->
    $cards = @$el.find('.card')
    $.map($cards, (el,i) ->
      $el = $(el)
      if $el.hasClass('card-empty')
        $el.removeClass('card-empty')
        $el.addClass('card-shirt')
    )

  # restore active card css to default
  #
  # @private
  clearCard: ->
    $card = @$el.find('.card.active')
    $card.css({left: 0, top: 0, 'z-index': 1})
    $card.attr('class', 'card active card-shirt')

class Game

  cards: []           # collection of card
  typeTurn: 'normal'  # normal of inverse, determine show face of cards or not
  turn: 1             # turn's count
  isRun: false        # prevent multiple runs

  options: {          # game options
    speed: 500
  }

  # initialize
  #
  # private
  constructor: ->
    @$el = $('#game-app')
    @assignEvents()
    @init()

  init: ->
    @user = new Player('user')
    @comp = new Player('comp')
    @initCards()
    @showTurn()
    @updatePlayersOptions()

  # assign all events
  #
  # @private
  assignEvents: ->
    $('#turn-btn') .on('click', $.proxy(@onClickTurn,   @))
    $('#reset-btn').on('click', $.proxy(@onClickReset,  @))
    $('#decrease-btn').on('click', $.proxy(@onClickDecrease, @))
    $('#increase-btn').on('click', $.proxy(@onClickIncrease, @))
    $('#shuffle-btn') .on('click', $.proxy(@onClickShuffle,  @))
    $('#change-shirt-btn').on('click', $.proxy(@onClickChangeShirt, @))
    $('#about-btn').on('click', $.proxy(@onClickAbout, @))
    $('.btn').on('selectstart', $.proxy(@onSelectStart, @)) # prevent selecting button

  # init pack of cards and share it to players
  #
  # @private
  initCards: ->
    pack = []
    for type in ['club', 'diamond', 'heart', 'spade']
      for power in [1..13]
        pack.push({type: type, power:power})
    pack = @shuffle(pack)
    @user.cards = pack[0..25]
    @comp.cards = pack[26..52]

    @user.updateCount()
    @comp.updateCount()

  # event on click turn button
  #
  # @private
  onClickTurn: (e)->
    e.preventDefault()

    if @isRunning() then return;
    @isRun = true

    @showTurn()
    @deactivateTurnButton()

    @user.moveCard(@cards, @typeTurn)
    @comp.moveCard(@cards, @typeTurn)

    if @typeTurn is 'inverse'
      @showMessage('Положите еще карту!')
      @typeTurn = 'normal'
    else if (player = @findWinner()) isnt null
      if player.name is 'user'
        @showMessage("Вы победили в этом ходу!", 'user')
      else
        @showMessage("Соперник победил в этом ходу!")
      @moveCardsBack(player)
    else
      @typeTurn = 'inverse'
      @showMessage('Победитель не определен! <br/> Сделайте еще ход!')

    @turn++

    if (winner = @findGameWinner()) isnt null
      if winner is true
        @showModal('Ничья', 'Игра окончена. Ничья!')
      else if winner.name is 'user'
        @moveCardsBack(winner)
        @showModal('Победа! :)', 'Удача была на вашей стороне! <br/> Вы победили!')
      else
        @moveCardsBack(winner)
        @showModal('Поражение :\'(', 'К сожалению, Вы проиграли!')
      @toggleButtons()
      @showMessage('')

    @isRun = false

  # event on click reset button
  #
  # @private
  onClickReset: (e)->
    e.preventDefault()
    if @isRunning() then return

    @isRun = true
    @reset()
    @init()

    @showMessage('Началась новая игра!')
    @isRun = false

  # event on select button
  #
  # @private
  onSelectStart: (e)->
    e.preventDefault()
    return false

  # event on click decrease button
  #
  # @private
  onClickDecrease: (e)->
    e.preventDefault()
    if @options['speed'] < 1000
      @options['speed'] = @options['speed'] + 100
      @changeSpeedText()
      @updatePlayersOptions()

  # show dialog with title and content
  #
  # @private
  showModal: (title, content)->
    $dialog = $('#dialog-modal')
    $dialog.find('#modal-title',).text(title)
    $dialog.find('.modal-body').html("<p>#{content}</p>")
    $dialog.modal('show')

  # event on click increase button
  #
  # @private
  onClickIncrease: (e)->
    e.preventDefault()
    if @options['speed'] > 100
      @options['speed'] = @options['speed'] - 100
      @changeSpeedText()
      @updatePlayersOptions()

  # event on click shuffle button
  #
  # @private
  onClickShuffle: (e)->
    e.preventDefault()
    @shuffle(@user.cards)
    @showMessage('Надеясь на удачу, вы решили перетасовать свою колоду карт.')

  # event on click change-shirt-btn, changing shirt of pack
  #
  # @private
  onClickChangeShirt: (e)->
    e.preventDefault()
    $body = $('body')
    currentShirt = $body.attr('class')

    if currentShirt is 'angry'
      shirt = 'army'
    else
      shirt = 'angry'
    $body.attr('class', shirt)
    @showMessage('Магическим образом колода карт изменила свою рубашку!')

  # event on click about-btn, show dialog
  #
  # @private
  onClickAbout: (e)->
    e.preventDefault()
    @showModal("Об авторе", $('#about').html())

  # event on click decrease button
  #
  # @private
  updatePlayersOptions: ->
    options = @options
    @user.options = options
    @comp.options = options

  # toggle turn and reset buttons visibility
  toggleButtons: ->
    @$el.find('#turn-btn').toggleClass('hide')
    @$el.find('#reset-btn').toggleClass('hide')

  deactivateTurnButton: ->
    @$el.find('#turn-btn').addClass('passive')

  # reset default settings and default view of the game
  #
  # @private
  reset: ->
    @turn = 1
    @typeTurn = 'normal'
    @cards = []
    @user.reset()
    @comp.reset()
    @toggleButtons()
    @$el.find('.card.active').attr('class', 'card active card-empty')

  # check what game actions is not executing
  #
  # @private
  isRunning: ->
    return @isRun or @user.isRun or @comp.isRun

  # send cards back to player from game collection
  #
  # @private
  moveCardsBack: (player)->
    for card in @cards
      player.cards.unshift(card)
    @cards = []
    player.isWinner = true

  # find winner of game if it was ended
  #
  # @private
  findGameWinner: ->
    compIsWinner = @user.getCountCards() is 0
    userIsWinner = @comp.getCountCards() is 0

    if userIsWinner and compIsWinner
      return true
    else if compIsWinner
      return @comp
    else if userIsWinner
      return @user
    else
      return null

  # find winner of turn
  #
  # @private
  findWinner: ->
    firstCard  = @cards.slice(-2, -1)[0]
    firstPower  = @countPower(firstCard)

    secondCard = @cards.slice(-1)[0]
    secondPower = @countPower(secondCard)

    if firstPower > secondPower
      return @[firstCard.player];
    else if firstPower < secondPower
      return @[secondCard.player];
    return null

  # change power of card if it is ace
  #
  # @private
  countPower: (card)->
    if card.power isnt 1 then card.power else 14

  # display message in console
  #
  # @private
  showMessage: (text, type)->
    if type? then text = "<span class='#{type}-text'>#{text}</span>"
    @$el.find('.console').html(text)

  # show number of turn
  #
  # @private
  showTurn: ->
    @$el.find('.turn-count').text(@turn)

  # change text of speed button
  #
  # @private
  changeSpeedText: ->
    speed = (500/@options['speed']*100).toFixed(0)
    @$el.find('#speed-text').text("#{speed}%")

  # shuffle collection of cards
  #
  # @private
  shuffle: (array) ->
    i = array.length
    while i
      j = parseInt(Math.random() * i)
      x = array[--i]
      array[i] = array[j]
      array[j] = x
    return array

$ ->
  new Game # run the game