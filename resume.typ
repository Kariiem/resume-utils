// Edit this file directly; it is the résumé's content and layout source.
// No package imports or system font installation required.
// Compile: typst compile resume.typ
#import "resume-icon-in-use.typ": icon

#set document(title: "Karim Taha — Resume", author: "Karim Taha")
#set page(paper: "us-letter", margin: (x: 0.45in, y: 0.35in), numbering: none)
#set text(
  font: "New Computer Modern",
  size: 10pt,
  lang: "en",
  hyphenate: false,
  top-edge: 0.7em,
  bottom-edge: -0.2em,
)
#set par(justify: false, leading: 3pt, spacing: 0pt)
#set list(indent: 10pt, body-indent: 5pt, spacing: 3pt, marker: [•])

// Sections may span pages; individual entries below stay together.
#let section(title, body) = block(
  width: 100%,
  breakable: true,
  above: 12pt,
  below: 0pt,
)[
  #text(size: 12pt, weight: "bold", title)
  #v(2pt)
  #line(length: 100%, stroke: 0.5pt)
  #v(6pt)
  #body
]

#let entry(
  title,
  date,
  organization: none,
  url: none,
  project: false,
  body,
) = block(
  width: 100%,
  breakable: false,
  above: 0pt,
  below: 8pt,
)[
  #grid(
    columns: (1fr, auto),
    column-gutter: 8pt,
    align: (left, right),
    text(size: 11.5pt, weight: "bold")[
      #if url == none { title } else {
        link(url)[#if project { underline(title) } else { title } #icon(
            "external",
            size: 8pt,
          )]
      }
    ],
    strong(date),
  )
  #if organization != none {
    v(2pt)
    organization
  }
  #v(4pt)
  #body
]

#let contact(kind, url, label) = link(url)[#icon(kind) #underline(label)]

#align(center)[
  #text(size: 25pt, smallcaps[Karim Taha])
  #v(2pt)
  #text(size: 11pt)[Cairo,Egypt]
  #v(3pt)
  #contact("phone", "tel:+201115643549", "+20-1115643549")
  #h(6pt)
  #contact(
    "email",
    "mailto:kariem.taha2.7@gmail.com",
    "kariem.taha2.7@gmail.com",
  )
  #h(6pt)
  #contact(
    "linkedin",
    "https://www.linkedin.com/in/karim-taha-6927711b8/",
    "Karim Taha",
  )
  #h(6pt)
  #contact("github", "https://github.com/Kariiem", "Kariiem")
]

#section("EDUCATION")[
  #grid(
    columns: (1fr, auto),
    column-gutter: 8pt,
    align: (left, right),
    text(size: 11.5pt, weight: "bold")[Cairo University Faculty of Engineering],
    strong[August 2018 – July 2023],

    emph[BSc. Computer Engineering, Grade: Excellent], emph[Cairo, Egypt],
  )
]

#section("EXPERIENCE")[
  #entry(
    "Backend Engineer (Elixir / OTP, CQRS/ES)",
    "August 2025 - Present",
    organization: [Sonnen],
  )[
    - Designed and extended CQRS/Event-Sourcing workflows using Commanded: introduced new commands/events and updated projectors and process managers to support cross-service domain logic.
    - Resolved a production aggregate state bug by redesigning event emission (two-event sequencing) to correctly handle timeouts and prevent incorrect state replacement involving Oban jobs.
    - Re-architected JSON logging pipeline to align with OTP 26+ logger handler,filter,formatter model, adding structured metadata for Phoenix/Plug requests.
    - Diagnosed and eliminated shutdown race conditions between dynamic supervisors and PubSub processes.
    - Designed and implemented a reusable RabbitMQ client library with explicit producer/consumer behaviours and blocked-connection handling via Phoenix.PubSub state broadcasting.
  ]
  #entry(
    "Parse error recovery and incrementality for GHC",
    "June 2024 - Nov 2024",
    organization: [Haskell.org (GSoC 2024)],
    url: "https://summerofcode.withgoogle.com/archive/2024/projects/3tNBjwL4",
  )[
    - GHC (Glasgow Haskell Compiler) is a state-of-the-art Haskell compiler, it's divided into several stages: parser, renamer, typechecker, desugarer and code gen.
    - GHC's parser is not fault-tolerant, so any parsing error causes the whole compilation pipeline to fail, this affects the programming experience, since it leads to longer modify-compile-correct cycles.
    - The project included two parts, the happy parser generator, and GHC's grammar file (happy user).
    - A form of recovery, namely resumable parsing was implemented in happy parser generator. It had to be modified so upon encountring an error, it shifts a ‘catch‘ token to the parsing stack, to determine where to resume parsing the grammar author should handle ‘catch‘ explicitly in the grammar.
    - The grammar file was modified to accept ‘catch‘ token in positions where we want to resume parsing and where parsing can be recovered by the surrounding context.
  ]
  #entry(
    "Improving FreeBSD User Emulation of the Armv7 Architecture",
    "June 2023 - Sept 2023",
    organization: [QEMU.org (GSoC 2023)],
    url: "https://summerofcode.withgoogle.com/programs/2023/projects/nPd0n4mh",
  )[
    - FreeBSD User is the name of the QEMU submodule for FreeBSD OS.
    - To improve the Armv7 emulation, a set of syscalls needed to be implemented in FreeBSD User. Issuing a syscall in the guest OS works by translating the addresses of the input parameters from the QEMU address space to the host address space, call the corresponding syscall on the host, then copy the output parameters, if any, to the QEMU address space.
    - The goal was to get a simple C++ hello-world program to compile and run inside an armv7 jail hosted on an amd64 machine using clang.
  ]
]

#section("PROJECTS")[
  #entry(
    "Lang",
    "May 2023",
    url: "https://github.com/Kariiem/Compiler",
    project: true,
  )[
    - A compiler for a statically typed, expression based programming language, written in C.
    - The implementation follows the literature standards, by dividing the compiler into a front-end and a back-end.
    - The front-end is done using flex/bison parser generators to generate a parser in C.
    - The back-end is divided into several stages: symbol tables constuction, type checking and code generation.
  ]
  #entry(
    "RSA Algorithm",
    "June 2022",
    url: "https://github.com/Kariiem/RSA-Algorithm",
    project: true,
  )[
    - Simple implementation of RSA algorithm in Haskell packaged as a cabal library.
    - Used the sockets api for communication between sender and receiver.
    - Implemented chosen cipher text attack.
  ]
  #entry(
    "VHDL Pipelined-Processor",
    "Jan 2022",
    url: "https://github.com/EssamWisam/Pipelined-AMD-Ryzen-9",
    project: true,
  )[
    - A Harvard-architecture 5-stage pipelined processor, implemented in VHDL using Intel's ModelSim.
    - The processor has a RISC-like instruction set architecture, with 8 word-sized general-purpose registers:R0-R7 and some special purpose registers: program counter(PC) And stack pointer(SP).
    - The memory address space is 1 MB of 16-bit width and is word addressable. The data bus is 32 bits.
  ]
  #entry(
    "Search engine",
    "June 2021",
    url: "https://github.com/Kariiem/7oksha.com",
    project: true,
  )[
    - Search engine in Java, using Java's multi-threading facilities, namely thread pools.
    - The Search engine is divided into two parts the web crawler and the indexer.
    - The Web Crawler recursively downloads a specified list of web pages, recurring on each sub link.
    - The Indexer reads every word, increases it's score then inserts the collected data into an SQL database, ready for query from a simple Web Gui.
  ]
]

#section("TECHNICAL SKILLS")[
  *Languages:* C/C++, Haskell, Python, javaScript/Typescript, SQL \
  *Developer Tools:* Emacs, Neovim, VS Code, GitHub \
  *Technologies/Frameworks:* FreeBSD, Linux, Git
]
