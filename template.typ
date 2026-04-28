#set page(
  fill: none, 
  margin: 2pt,
);

#let display(body) = context {
  let m = measure(body)
  set page(width: m.width + page.margin.length*2, height: m.height + page.margin.length*2)
  body
}

#display()[$pi^2$]
