#show math.equation: set text(font: "New Computer Modern Math")
#show math.text: set text(font: "New Computer Modern")

#let display(body) = context {
  let margin = 2pt
  let m = measure(body)
  set page(
    fill: none,
    margin: margin,
    width: m.width + margin*2, 
    height: m.height + margin*2,
  )
  body
}

#display()[$ !! $]
