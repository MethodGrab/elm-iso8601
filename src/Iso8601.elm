module Iso8601 exposing (fromTime, toTime)

{-| Convert between ISO-8601 date strings and POSIX times.
-}

import Parser exposing ((|.), (|=), Count(..), Parser, int, keep, map, oneOf, succeed, symbol)
import Time exposing (Month(..), utc)


{-| Convert from an ISO-8601 date string to a `Time.Posix` value.

ISO-8601 date strings sometimes specify things in UTC. Other times, they specify
a non-UTC time as well as a UTC offset. Regardless of which format the ISO-8601
string uses, this function normalizes it and returns a time in UTC.

-}
toTime : String -> Result Parser.Error Time.Posix
toTime str =
    Parser.run iso8601 str


{-| A fixed-length integer padded with zeroes.
-}
paddedInt : Int -> Parser Int
paddedInt quantity =
    keep (Exactly quantity) Char.isDigit
        |> Parser.andThen
            (\str ->
                case String.toInt str of
                    Just intVal ->
                        Parser.succeed intVal

                    Nothing ->
                        Parser.fail ("Invalid integer: \"" ++ str ++ "\"")
            )


{-| 365 * 24 * 60 * 60 * 1000
-}
msPerYear : Int
msPerYear =
    31536000000


{-| 24 * 60 * 60 * 1000
-}
msPerDay : Int
msPerDay =
    86400000


{-| A parsed day was outside the valid month range. (e.g. 0 is never a valid
day in a month, and neither is 32.
-}
invalidDay : Int -> Parser Int
invalidDay day =
    Parser.fail ("Invalid day: " ++ String.fromInt day)


epochYear : Int
epochYear =
    1970


yearMonthDay : ( Int, Int, Int ) -> Parser Int
yearMonthDay ( year, month, dayInMonth ) =
    if dayInMonth < 0 then
        invalidDay dayInMonth
    else
        let
            succeedWith extraMs =
                let
                    days =
                        if month < 3 || not (isLeapYear year) then
                            -- If we're in January or February, it doesn't matter
                            -- if we're in a leap year from a days-in-month perspective.
                            -- Only possible impact of laep years in this scenario is
                            -- if we received February 29, which is checked later.
                            -- Also, this doesn't matter if we explicitly aren't
                            -- in a leap year.
                            dayInMonth - 1
                        else
                            -- We're in a leap year in March-December, so add an extra
                            -- day (for Feb 29) compared to what we'd usually do.
                            dayInMonth

                    dayMs =
                        -- one extra day for each leap year
                        msPerDay * (days + leapYearsBetween epochYear year)

                    yearMs =
                        msPerYear * (year - epochYear)
                in
                Parser.succeed (extraMs + yearMs + dayMs)
        in
        case month of
            1 ->
                -- 31 days in January
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- Add 0 days when in the first month of the year
                    succeedWith 0

            2 ->
                -- 28 days in February unless it's a leap year; then 29)
                if (dayInMonth > 29) || (dayInMonth == 29 && not (isLeapYear year)) then
                    invalidDay dayInMonth
                else
                    -- 31 days in January
                    -- (31 * 24 * 60 * 60 * 1000)
                    succeedWith 2678400000

            3 ->
                -- 31 days in March
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 28 days in February (leap years are handled elsewhere)
                    -- ((28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 5097600000

            4 ->
                -- 30 days in April
                if dayInMonth > 30 then
                    invalidDay dayInMonth
                else
                    -- 31 days in March
                    -- ((31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 7776000000

            5 ->
                -- 31 days in May
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 30 days in April
                    -- ((30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 10368000000

            6 ->
                -- 30 days in June
                if dayInMonth > 30 then
                    invalidDay dayInMonth
                else
                    -- 31 days in May
                    -- ((31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 13046400000

            7 ->
                -- 31 days in July
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 30 days in June
                    -- ((30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 15638400000

            8 ->
                -- 31 days in August
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 31 days in July
                    -- ((31 + 30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 18316800000

            9 ->
                -- 30 days in September
                if dayInMonth > 30 then
                    invalidDay dayInMonth
                else
                    -- 31 days in August
                    -- ((31 + 31 + 30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 20995200000

            10 ->
                -- 31 days in October
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 30 days in September
                    -- ((30 + 31 + 31 + 30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 23587200000

            11 ->
                -- 30 days in November
                if dayInMonth > 30 then
                    invalidDay dayInMonth
                else
                    -- 31 days in October
                    -- ((31 + 30 + 31 + 31 + 30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 26265600000

            12 ->
                -- 31 days in December
                if dayInMonth > 31 then
                    invalidDay dayInMonth
                else
                    -- 30 days in November
                    -- ((30 + 31 + 30 + 31 + 31 + 30 + 31 + 30 + 31 + 28 + 31) * 24 * 60 * 60 * 1000)
                    succeedWith 28857600000

            _ ->
                Parser.fail ("Invalid month: \"" ++ String.fromInt month ++ "\"")


fromParts : Int -> Int -> Int -> Int -> Int -> Int -> Time.Posix
fromParts monthYearDayMs hour minute second ms utcOffsetMinutes =
    Time.millisToPosix
        (monthYearDayMs
            + (hour * 60 * 60 * 1000)
            -- Incoroprate and discard UTC offset
            + ((minute - utcOffsetMinutes) * 60 * 1000)
            + (second * 1000)
            + ms
        )


{-| From <https://www.timeanddate.com/date/leapyear.html>

In the Gregorian calendar three criteria must be taken into account to identify leap years:

  - The year can be evenly divided by 4;
  - If the year can be evenly divided by 100, it is NOT a leap year, unless;
  - The year is also evenly divisible by 400. Then it is a leap year.

This means that in the Gregorian calendar, the years 2000 and 2400 are leap years, while 1800, 1900, 2100, 2200, 2300 and 2500 are NOT leap years.

-}
isLeapYear : Int -> Bool
isLeapYear year =
    (modBy 4 year == 0) && ((modBy 100 year /= 0) || (modBy 400 year == 0))


{-| Based on <https://stackoverflow.com/a/14883770/2334666>
-}
leapYearsBetween : Int -> Int -> Int
leapYearsBetween lower higher =
    if lower == higher then
        0
    else if lower > higher then
        -- We got passed the higher one first, so swap the arguments.
        leapYearsBetween higher lower
    else if lower < 1800 || higher > 9999 then
        slowLeapYearsBetween 0 lower higher
    else
        let
            -- By default, it's a leap year if it's divisible by 4.
            defaultLeapYears =
                (lower // 4) - ((higher - 1) // 4)

            nonLeapYears =
                -- It's not a leap year if it's divisible by 100
                ((lower // 100) - ((higher - 1) // 100))
                    - -- It *is* a leap year if it's divisible by 400
                      ((lower // 400) - ((higher - 1) // 400))
        in
        defaultLeapYears - nonLeapYears


{-| Fallback for years outside the range leapYearsBetween handles (quickly).
-}
slowLeapYearsBetween : Int -> Int -> Int -> Int
slowLeapYearsBetween count startYear endYear =
    if startYear >= endYear then
        count
    else if isLeapYear startYear then
        slowLeapYearsBetween (count + 1) (startYear + 1) endYear
    else
        slowLeapYearsBetween count (startYear + 1) endYear


{-| YYYY-MM-DDTHH:mm:ss.sssZ or ±YYYYYY-MM-DDTHH:mm:ss.sssZ
-}
iso8601 : Parser Time.Posix
iso8601 =
    -- TODO account for format variations, including those with UTC offsets
    succeed fromParts
        |= monthYearDayInMs
        -- YYYY-MM-DD
        |. symbol "T"
        |= paddedInt 2
        -- HH
        |. symbol ":"
        |= paddedInt 2
        -- mm
        |. symbol ":"
        |= paddedInt 2
        -- ss
        |. symbol "."
        |= paddedInt 3
        -- SSS
        |= oneOf
            [ -- "Z" means UTC
              map (\_ -> 0) (symbol "Z")

            -- +05:00 means UTC+5 whereas -11:30 means UTC-11.5
            , succeed utcOffsetMinutesFromParts
                |= oneOf
                    [ map (\_ -> 1) (symbol "+")
                    , map (\_ -> -1) (symbol "-")
                    ]
                |= int
                |. symbol ":"
                |= int
            ]


{-| Parse the year, month, and day, and convert to milliseconds since the epoch.

We need all three pieces information at once to do this conversion, because of
leap years. Without knowing Month, Year, and Day, we can't tell whether to
succeed or fail when we encounter February 29.

-}
monthYearDayInMs : Parser Int
monthYearDayInMs =
    Parser.succeed (\year month day -> ( year, month, day ))
        |= paddedInt 4
        -- YYYY
        |. symbol "-"
        |= paddedInt 2
        -- MM
        |. symbol "-"
        |= paddedInt 2
        -- DD
        |> Parser.andThen yearMonthDay


utcOffsetMinutesFromParts : Int -> Int -> Int -> Int
utcOffsetMinutesFromParts multiplier hours minutes =
    -- multiplier is either 1 or -1 (for negative UTC offsets)
    multiplier * ((hours * 60) + minutes)


{-| Inflate a Posix integer into a more memory-intensive ISO-8601 date string.

It's generally best to avoid doing this unless an external API requires it.

(UTC integers are less error-prone, take up less memory, and are more efficient
for time arithmetic.)

Format: YYYY-MM-DDTHH:mm:ss.sssZ

-}
fromTime : Time.Posix -> String
fromTime time =
    ---- YYYY
    toPaddedString 4 (Time.toYear utc time)
        ++ "-"
        -- MM
        ++ fromMonth (Time.toMonth utc time)
        ++ "-"
        -- DD
        ++ toPaddedString 2 (Time.toDay utc time)
        ++ "T"
        -- HH
        ++ toPaddedString 2 (Time.toHour utc time)
        ++ ":"
        -- mm
        ++ toPaddedString 2 (Time.toMinute utc time)
        ++ ":"
        -- ss
        ++ toPaddedString 2 (Time.toSecond utc time)
        ++ ":"
        -- sss
        ++ toPaddedString 2 (Time.toMillis utc time)
        ++ "Z"


toPaddedString digits time =
    String.padLeft digits '0' (String.fromInt time)


fromMonth : Time.Month -> String
fromMonth month =
    case month of
        Jan ->
            "01"

        Feb ->
            "02"

        Mar ->
            "03"

        Apr ->
            "04"

        May ->
            "05"

        Jun ->
            "06"

        Jul ->
            "07"

        Aug ->
            "08"

        Sep ->
            "09"

        Oct ->
            "10"

        Nov ->
            "11"

        Dec ->
            "12"