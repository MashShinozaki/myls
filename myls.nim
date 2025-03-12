import std/[cmdline, dirs, paths, strformat, strutils, terminal, unicode]

const
    USAGE = "usage: myls [DIRECTORY]"

    separator = " | "
    padding_char = ' '

type
    ContentType = enum
        cFile
        cDir
    
    Element = object
        name : string
        width: int
        color: ForegroundColor
    
    Arrangement = tuple
        num_rows  : int
        num_cols  : int
        max_widths: seq[int]

func getColor(name: string, content_type: ContentType): ForegroundColor =
    return case name.toLower()
        of "red":
            fgRed
        of "green":
            fgGreen
        of "blue":
            fgBlue
        of "yellow":
            fgYellow
        of "cyan":
            fgCyan
        of "white":
            fgWhite
        of "black":
            fgBlack
        else:
            case content_type:
            of cFile:
                fgCyan
            of cDir:
                fgGreen

func runeWidthOf(rune: Rune): int =
    return case int(rune)
        of 0x2460..0x2473: # Circled numbers
            1
        of 0x2474..0x2487: # Parenthesized numbers
            1
        of 0x2488..0x249B: # Numbers period
            1
        of 0x249C..0x24B5: # Parenthesized Latin letters
            1
        of 0x24B6..0x24E9: # Circled Latin letters
            1
        of 0x24EA: # Additional circled number
            1
        of 0x24EB..0x24F4: # White on black circled numbers
            1
        of 0x24F5..0x24FE: # Double circled numbers
            1
        of 0x24FF: # Additional white on black circled number
            1
        else:
            if rune.isCombining() or rune.size() < 3:
                1
            else:
                2

func stringWidthOf(str: string): int =
    var width = 0
    for rune in str.toRunes():
        width += runeWidthOf(rune)
    return width

proc elementsIn(dir: Path): seq[Element] =
    const
        file_color {.strdefine.} = "cyan"
        dir_color {.strdefine.} = "green"

        f_color = getColor(file_color, cFile)
        d_color = getColor(dir_color, cDir)

    var elems = newSeq[Element]()
    for component, path in walkDir(dir):
        let name = string(lastPathPart(path))
        var
            is_element = true
            color = fgWhite

        case component
        of pcFile:
            color = f_color
        of pcDir:
            color = d_color
        else:
            is_element = false

        if is_element:
            let width = stringWidthOf(name)
            elems.add(Element(name: name, width: width, color: color))
    
    return elems

func calcNumCols(num_elems: int, num_rows: int): int =
    let remainder = num_elems mod num_rows
    let num_full_cols = num_elems div num_rows
    return if remainder == 0: num_full_cols else: num_full_cols + 1

func calcIndex(row: int, col: int, num_rows: int): int =
    return row + num_rows * col

proc arrangementOf(elems: seq[Element]): Arrangement =
    let
        terminal_width = terminalWidth()
        num_elems = elems.len
    var
        num_rows = 1
        num_cols = num_elems
        max_widths = newSeq[int](num_elems)
    
    while num_cols > 1:
        for col in 0 ..< num_cols:
            max_widths[col] = 0
        
        for row in 0 ..< num_rows:
            for col in 0 ..< num_cols:
                let idx = calcIndex(row, col, num_rows)
                var width = 0

                if idx < num_elems:
                    let elem = elems[idx]
                    width = if col == num_cols - 1: elem.width else: elem.width + separator.len

                max_widths[col] = max(width, max_widths[col])
        
        var row_width = 0
        for col in 0 ..< num_cols:
            row_width += max_widths[col]
        
        if row_width > terminal_width:
            num_rows += 1
            num_cols = calcNumCols(num_elems, num_rows)
        else:
            break
    
    return (
        num_rows  : num_rows,
        num_cols  : num_cols,
        max_widths: max_widths
    )

proc listDown(dir: Path) =
    if not dirExists(dir):
        stderr.writeLine(fmt"directory `{dir}` does not exist")
        return
    
    let
        elems = elementsIn(dir)
        num_elems = elems.len
    
    if num_elems == 0:
        return

    let (num_rows, num_cols, max_widths) = arrangementOf(elems)
    
    if num_cols == 1:
        for elem in elems:
            stdout.styledWriteLine(elem.color, elem.name)
    else:
        for row in 0 ..< num_rows:
            for col in 0 ..< num_cols:
                let idx = calcIndex(row, col, num_rows)
                if idx >= num_elems:
                    break

                let elem = elems[idx]
                stdout.styledWrite(elem.color, elem.name)

                if col < num_cols - 1:
                    let
                        padding_len = max_widths[col] - elem.width - separator.len
                        padding = padding_char.repeat(padding_len)
                        postfix = padding & separator

                    stdout.write(postfix)

            stdout.write("\n")

proc main() =
    let argc = paramCount()
    if argc > 1:
        stderr.writeLine(USAGE)
        stderr.write("\n")
        stderr.writeLine("only up to one argument is allowed")
    else:
        let dir = if argc == 1: Path(paramStr(1)) else: getCurrentDir()
        listDown(dir)

main()
