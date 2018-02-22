{Tool} = require './base'
{createShape} = require '../core/shapes'
SELECT_RECT_SIZE = 25

module.exports = class SelectShape extends Tool
  name: 'SelectShape'
  usesSimpleAPI: false

  constructor: (lc) ->
    # This is a 'shadow' canvas -- we'll reproduce the shapes here, each shape
    # with a different color that corresponds to their index. That way we'll
    # be able to find which shape to select on the main canvas by pixel color.
    @selectCanvas = document.createElement('canvas')
    @selectCanvas.style['background-color'] = 'transparent'
    @selectCtx = @selectCanvas.getContext('2d')

  didBecomeActive: (lc) ->
    selectShapeUnsubscribeFuncs = []
    @_selectShapeUnsubscribe = =>
      for func in selectShapeUnsubscribeFuncs
        func()

    onDown = ({ x, y }) =>
      @didDrag = false

      shapeIndex = @_getPixel(x, y, lc, @selectCtx)
      @selectedShape = lc.shapes[shapeIndex]

      if @selectedShape?
        lc.trigger 'shapeSelected', { @selectedShape }
        lc.setShapesInProgress [@selectedShape, createShape('SelectionBox', {
          shape: @selectedShape,
          handleSize: 0
        })]
        lc.repaintLayer 'main'

        br = @selectedShape.getBoundingRect()
        @dragOffset = {
          x: x - br.x,
          y: y - br.y
        }
      else
        lc.setShapesInProgress []
        lc.repaintLayer 'main'

    onDrag = ({ x, y }) =>
      if @selectedShape?
        @didDrag = true

        @selectedShape.setUpperLeft {
          x: x - @dragOffset.x,
          y: y - @dragOffset.y
        }
        lc.setShapesInProgress [@selectedShape, createShape('SelectionBox', {
          shape: @selectedShape,
          handleSize: 0
        })]
        lc.repaintLayer 'main'

    onUp = ({ x, y }) =>
      if @didDrag
        @didDrag = false
        lc.trigger('shapeMoved', { shape: @selectedShape })
        lc.trigger('drawingChange', {})
        lc.repaintLayer('main')
        @_drawSelectCanvas(lc)

    selectShapeUnsubscribeFuncs.push lc.on 'lc-pointerdown', onDown
    selectShapeUnsubscribeFuncs.push lc.on 'lc-pointerdrag', onDrag
    selectShapeUnsubscribeFuncs.push lc.on 'lc-pointerup', onUp

    @_drawSelectCanvas(lc)

  willBecomeInactive: (lc) ->
    @_selectShapeUnsubscribe()
    lc.setShapesInProgress []

  _drawSelectCanvas: (lc) ->
    @selectCanvas.width = lc.canvas.width
    @selectCanvas.height = lc.canvas.height
    @selectCtx.clearRect(0, 0, @selectCanvas.width, @selectCanvas.height)
    shapes = lc.shapes.map (shape, index) =>
      createShape('SelectionBox', {
        shape: shape,
        handleSize: 0,
        backgroundColor: "##{@_intToHex(index)}"
      })
    lc.draw(shapes, @selectCtx)

  _intToHex: (i) ->
    "000000#{i.toString 16}".slice(-6)

  _getPixel: (x, y, lc, ctx) ->
    point = lc.drawingCoordsToClientCoords x, y
    pixel = ctx.getImageData(point.x, point.y, 1, 1).data
    pixelVisible = lc.ctx.getImageData(point.x - SELECT_RECT_SIZE / 2, point.y - SELECT_RECT_SIZE / 2, SELECT_RECT_SIZE, SELECT_RECT_SIZE).data
    if !@_every(pixelVisible, (x) -> x == 0) and pixel[3]
      parseInt @_rgbToHex(pixel[0], pixel[1], pixel[2]), 16
    else
      null

  _componentToHex: (c) ->
    hex = c.toString(16);
    "0#{hex}".slice -2

  _rgbToHex: (r, g, b) ->
    "#{@_componentToHex(r)}#{@_componentToHex(g)}#{@_componentToHex(b)}"

  _every: (arr, func) ->
    (return false if not func x) for x in arr
    return true

