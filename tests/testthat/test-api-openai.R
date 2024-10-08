test_that("default model is reported", {
  expect_snapshot(. <- new_chat_openai()$chat("Hi"))
})

test_that("can make simple request", {
  chat <- new_chat_openai("Be as terse as possible; no punctuation")
  resp <- chat$chat("What is 1 + 1?")
  expect_match(resp, "2")

  resp <- sync(chat$chat_async("What is 1 + 1?"))
  expect_match(resp, "2")
})

test_that("can make simple streaming request", {
  chat <- new_chat_openai("Be as terse as possible; no punctuation")
  resp <- coro::collect(chat$stream("What is 1 + 1?"))
  expect_match(paste0(unlist(resp), collapse = ""), "2")

  resp <- sync(coro::async_collect(chat$stream_async("1 + 1")))
  expect_match(paste0(unlist(resp), collapse = ""), "2")
})


test_that("system prompt can be passed explicitly or as a turn", {
  system_prompt <- "Return very minimal output, AND ONLY USE UPPERCASE."

  chat <- new_chat_openai(system_prompt = system_prompt)
  resp <- chat$chat("What is the name of Winnie the Pooh's human friend?")
  expect_match(resp, "CHRISTOPHER ROBIN")
  expect_length(chat$turns(), 2)

  chat <- new_chat_openai(turns = list(turn("system", system_prompt)))
  resp <- chat$chat("What is the name of Winnie the Pooh's human friend?")
  expect_match(resp, "CHRISTOPHER ROBIN")
  expect_length(chat$turns(), 2)
})

test_that("existing conversation history is used", {
  chat <- new_chat_openai(turns = list(
    turn("system", "Return very minimal output; no punctuation."),
    turn("user", "List the names of any 8 of Santa's 9 reindeer."),
    turn("assistant", "Dasher, Dancer, Vixen, Comet, Cupid, Donner, Blitzen, and Rudolph.")
  ))
  expect_length(chat$turns(), 2)

  resp <- chat$chat("Who is the remaining one? Just give the name")
  expect_equal(resp, "Prancer")
  expect_length(chat$turns(), 4)
})

# Tool calls -------------------------------------------------------------------

test_that("can make a simple tool call", {
  get_date <- function() "2024-01-01"
  chat <- new_chat_openai(system_prompt = "Be very terse, not even punctuation.")
  chat$register_tool(get_date, "get_date", "Gets the current date", list())

  result <- chat$chat("What's the current date in YMD format?")
  expect_match(result, "2024-01-01")

  result <- chat$chat("What month is it?")
  expect_match(result, "January")
})

test_that("can make an async tool call", {
  get_date <- coro::async(function() {
    await(coro::async_sleep(0.2))
    "2024-01-01"
  })
  chat <- new_chat_openai(system_prompt = "Be very terse, not even punctuation.")
  chat$register_tool(get_date, "get_date", "Gets the current date", list())

  result <- sync(chat$chat_async("What's the current date in YMD format?"))
  expect_match(result, "2024-01-01")

  expect_snapshot(chat$chat("Great. Do it again."), error = TRUE)
})

test_that("can call multiple tools in parallel", {
  chat <- new_chat_openai(system_prompt = "Be very terse, not even punctuation.")
  favourite_color <- function(person) {
    if (person == "Joe") "sage green" else "red"
  }
  chat$register_tool(
    favourite_color,
    "favourite_color",
    "Returns a person's favourite colour",
    list(person = tool_arg("string", "Name of a person")),
    strict = TRUE
  )

  result <- chat$chat("
    What are Joe and Hadley's favourite colours?
    Answer like name1: colour1, name2: colour2
  ")
  expect_identical(result, "Joe: sage green, Hadley: red")
  expect_length(chat$turns(), 4)
})

test_that("can call multiple tools in sequence", {
  chat <- new_chat_openai(system_prompt = "Be very terse, not even punctuation.")
  chat$register_tool(
    function() 2024,
    "get_year",
    "Get the current year",
    list()
  )
  chat$register_tool(
    function(year) if (year == 2024) "Susan" else "I don't know",
    "popular_name",
    "Gets the most popular name for a year",
    list(year = tool_arg("integer", "Year"))
  )

  result <- chat$chat("What was the most popular name this year?")
  expect_equal(result, "Susan")
  expect_length(chat$turns(), 6)
})

# Images -----------------------------------------------------------------

test_that("can use images (inline and remote)", {
  chat <- new_chat_openai(model = "gpt-4o-mini")
  response <- chat$chat(
    "What's in this image? (Be sure to mention the outside shape)",
    content_image_file(system.file("httr2.png", package = "elmer"))
  )
  expect_match(response, "hex")
  expect_match(response, "baseball")

  chat <- new_chat_openai(model = "gpt-4o-mini")
  response <- chat$chat(
    "What's in this image? (Be sure to mention the outside shape)",
    content_image_url("https://httr2.r-lib.org/logo.png")
  )
  expect_match(response, "hex")
  expect_match(response, "baseball")
})
