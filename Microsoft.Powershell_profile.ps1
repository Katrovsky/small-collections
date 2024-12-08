function prompt {
    class Color {
        [int] $R
        [int] $G
        [int] $B

        static [Color] $Default = $null

        Color([int] $r, [int] $g, [int] $b) {
            $this.R = $r
            $this.G = $g
            $this.B = $b
        }

        static [string] Foreground([Color] $color) {
            if ($color) {
                return "$([char]0x1B)[38;2;$($color.R);$($color.G);$($color.B)m"
            }
            else {
                return "$([char]0x1B)[39m"
            }
        }

        static [string] Background([Color] $color) {
            if ($color) {
                return "$([char]0x1B)[48;2;$($color.R);$($color.G);$($color.B)m"
            }
            else {
                return "$([char]0x1B)[49m"
            }
        }
    }

    class PromptBuilder {
        hidden [string] $Text
        hidden [Color] $Foreground
        hidden [Color] $Background
        hidden [string] $Separator
        hidden [string] $ReversedSeparator

        PromptBuilder() {
            $this.Text = ""
            $this.Foreground = $null
            $this.Background = $null
            $this.Separator = $null
            $this.ReversedSeparator = $null
        }

        hidden PromptBuilder(
            [string] $text,
            [Color] $foreground,
            [Color] $background,
            [string] $separator,
            [string] $reversedSeparator
        ) {
            $this.Text = $text
            $this.Foreground = $foreground
            $this.Background = $background
            $this.Separator = $separator
            $this.ReversedSeparator = $reversedSeparator
        }

        [PromptBuilder] WithForeground([Color] $color) {
            return [PromptBuilder]::new(
                $this.Text,
                $color,
                $this.Background,
                $this.Separator,
                $this.ReversedSeparator
            )
        }

        [PromptBuilder] WithSection([string] $text) {
            return $this.WithSection($text, $this.Background)
        }

        [PromptBuilder] WithSection([string] $text, [Color] $background) {
            return [PromptBuilder]::new(
                "$($this.Text)$([Color]::Foreground($background))$([Color]::Background($this.Background))$($this.ReversedSeparator)$([Color]::Foreground($this.Background))$([Color]::Background($background))$($this.Separator)$([Color]::Foreground($this.Foreground))$text",
                $this.Foreground,
                $background,
                $null,
                $null
            )
        }

        [PromptBuilder] WithSeparator([char] $separator) {
            return [PromptBuilder]::new(
                $this.Text,
                $this.Foreground,
                $this.Background,
                "$separator",
                $null
            )
        }

        [PromptBuilder] WithoutSeparator() {
            return [PromptBuilder]::new(
                $this.Text,
                $this.Foreground,
                $this.Background,
                $null,
                $null
            )
        }

        [PromptBuilder] WithReversedSeparator([char] $separator) {
            return [PromptBuilder]::new(
                $this.Text,
                $this.Foreground,
                $this.Background,
                $null,
                "$separator"
            )
        }

        [string] ToString() {
            $final = $this.WithForeground([Color]::Default).WithSection("", [Color]::Default)
            return $final.Text
        }
    }

    $path = $(Get-Location).Path
    $sections = $path.Split([char]'\')
    $level = 0

    $colors = @{
        "Drive" = [Color]::new(227, 146, 52)
        "Home" = [Color]::new(52, 128, 235)
        "Project" = [Color]::new(54, 109, 186)
        "Alternate" = [Color]::new(99, 99, 99)
    }

    $git_root = -1
    $git_branch = $null
    if ($(git rev-parse --is-inside-work-tree) -eq "true") {
        $git_root = $(git rev-parse --show-toplevel).Split([char]'/').Length - 1
        $git_branch = $(git rev-parse --abbrev-ref HEAD)
    }
    
    $builder = [PromptBuilder]::new()    
    $builder = $builder.WithReversedSeparator(0xE0CA)

    if ($sections[0].EndsWith(":")) {
        $builder = $builder.WithSection(" $($sections[0].TrimEnd([char]':')) ", $colors["Drive"])
        $builder = $builder.WithSeparator(0xE0B4)
        $level += 1
    }

    foreach ($section in $sections[$level..($sections.Length-1)]) {
        $sectionColor = $colors["Alternate"]
        
        switch ($section) {
            ".git" { $sectionColor = [Color]::new(70, 138, 74) }
            "venv" { $sectionColor = [Color]::new(54, 109, 186) }
            "env" { $sectionColor = [Color]::new(54, 109, 186) }
            ".venv" { $sectionColor = [Color]::new(54, 109, 186) }
            ".env" { $sectionColor = [Color]::new(54, 109, 186) }
            "src" { $sectionColor = $colors["Project"] }
            "apps" { $sectionColor = $colors["Project"] }
            "lib" { $sectionColor = $colors["Project"] }
            "tests" { $sectionColor = [Color]::new(186, 54, 54) }
        }

        if ($section -eq $sections[$git_root]) {
            $builder = $builder.WithSection(" $section ", [Color]::new(70, 138, 74))
            $builder = $builder.WithSeparator(0xE0A0)
            $builder = $builder.WithSection(" $git_branch ", [Color]::new(72, 163, 77))
        }
        else {
            $builder = $builder.WithSection(" $section ", $sectionColor)
            $builder = $builder.WithSeparator(0xE0B8)
        }
    }

    $builder = $builder.WithoutSeparator()
    $builder = $builder.WithSeparator(0xE0B0)
    $builder = $builder.WithSection(" ", [Color]::Default)

    return $builder.ToString()
}
