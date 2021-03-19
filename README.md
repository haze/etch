# Etch
etch is a compile time tuned templating engine. etch focuses on speed and simplicity

###### goals
* be easy to use; provide a similar api to std.fmt.format (with more thought out qualifiers)
* be fast. I am providing the structure and data layout up front, it should be fast to create a result

###### non-goals
* be complex. I don't want to embed another dsl / language into my template engine, i should instead provide my data in a computed format
* be feature complete with other template engines (go, jinja, tera, sailfish, etc)

###### maybe-goals
* runtime use
