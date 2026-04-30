#let display(param, body) = context {
  show math.equation: set text(font: "New Computer Modern Math")
  show math.text: set text(font: "New Computer Modern")

  let m = measure(body)

  let data = param(m)

  set page(
    fill: none,
    margin: data.margin,
    width: data.width, 
    height: data.height,
  )
  
  body
}

