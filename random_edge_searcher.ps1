#requires -Version 5.0
# Random Edge Searcher
# Runs random nonsense Bing searches in Microsoft Edge while Edge is the
# active (foreground) window. Phrases are persisted to used_searches.txt
# and never repeated, even across restarts.

# ---------------- Config ----------------
$IntervalSeconds   = 15      # seconds between searches while Edge is active
$MaxGenerateTries  = 2000    # how hard to try to find an unused phrase

# ---------------- Paths -----------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UsedFile  = Join-Path $ScriptDir 'used_searches.txt'

# ---------------- Win32 -----------------
if (-not ('REMS.Win32' -as [type])) {
    Add-Type -Namespace REMS -Name Win32 -MemberDefinition @"
[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
"@
}

function Test-EdgeActive {
    $hwnd = [REMS.Win32]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) { return $false }
    $procId = 0
    [void][REMS.Win32]::GetWindowThreadProcessId($hwnd, [ref]$procId)
    if ($procId -le 0) { return $false }
    try {
        $proc = Get-Process -Id $procId -ErrorAction Stop
        return ($proc.ProcessName -ieq 'msedge')
    } catch { return $false }
}

# ---------------- Word lists ----------------
$Nouns = @(
    'apple','banana','dog','cat','car','tree','river','mountain','computer','phone',
    'chair','table','book','pencil','cloud','star','moon','sun','ocean','forest',
    'robot','dragon','wizard','ninja','pirate','monkey','elephant','tiger','lion','fish',
    'bird','snake','frog','mouse','rabbit','hamster','turtle','dolphin','whale','shark',
    'bear','wolf','fox','deer','owl','parrot','eagle','butterfly','ant','spider',
    'pizza','taco','sandwich','cookie','donut','muffin','cupcake','pancake','waffle','bagel',
    'sock','hat','shoe','jacket','glove','umbrella','backpack','clock','lamp','mirror',
    'window','door','bridge','tunnel','rocket','submarine','tractor','bicycle','scooter','train'
)

$Verbs = @(
    'crosses','eats','jumps over','sleeps near','runs from','dances with','talks to','fights',
    'kisses','paints','builds','breaks','finds','loses','hides from','chases','watches',
    'throws','catches','drops','lifts','drags','rolls','kicks','sings to','reads','writes',
    'draws','copies','follows','leads','pushes','pulls','opens','closes','climbs',
    'swims with','flies over','drives past','walks past','greets','ignores','tickles','pokes'
)

$Places = @(
    'store','park','school','hospital','beach','library','museum','restaurant','mall','gym',
    'garden','kitchen','basement','attic','garage','jungle','castle','cave','factory','airport',
    'station','theater','stadium','bakery','farm','zoo','aquarium','arcade','rooftop','dock'
)

$Adjectives = @(
    'tiny','huge','blue','red','sparkly','grumpy','sleepy','hungry','angry','quiet',
    'loud','fluffy','slimy','ancient','futuristic','magical','broken','shiny','dusty',
    'glowing','frozen','burning','invisible','fuzzy','smelly','wobbly','crispy','soggy',
    'cheerful','suspicious'
)

# ---------------- Templates ----------------
# Each template is a pattern with {0}, {1}, ... slots and a parallel list of
# slot kinds: n=noun, v=verb, p=place, a=adjective.
$Templates = @(
    @{ pattern = 'the {0} {1} the {2} to where';        slots = @('n','v','n') },
    @{ pattern = '{0} go to which {1}';                  slots = @('n','p') },
    @{ pattern = '{0} {1} {2} when';                     slots = @('n','v','n') },
    @{ pattern = 'why does {0} {1} {2}';                 slots = @('n','v','n') },
    @{ pattern = 'how can {0} {1} the {2}';              slots = @('n','v','n') },
    @{ pattern = 'when did the {0} {1} the {2}';         slots = @('n','v','n') },
    @{ pattern = 'where is the {0} {1}';                 slots = @('a','n') },
    @{ pattern = '{0} and {1} are {2}';                  slots = @('n','n','a') },
    @{ pattern = 'can {0} {1} a {2}';                    slots = @('n','v','n') },
    @{ pattern = 'does {0} {1} like {2}';                slots = @('n','v','n') },
    @{ pattern = 'the {0} {1} {2} a {3}';                slots = @('a','n','v','n') },
    @{ pattern = 'what if {0} {1} {2}';                  slots = @('n','v','n') },
    @{ pattern = 'is {0} {1} or {2}';                    slots = @('n','a','a') },
    @{ pattern = '{0} {1} the {2} {3}';                  slots = @('n','v','a','n') },
    @{ pattern = 'how does a {0} {1} {2}';               slots = @('a','n','v') },
    @{ pattern = 'why is the {0} {1} in the {2}';        slots = @('a','n','p') },
    @{ pattern = 'where did {0} go after the {1}';       slots = @('n','n') },
    @{ pattern = '{0} suddenly {1} a {2}';               slots = @('n','v','n') },
    @{ pattern = 'has {0} ever {1} a {2}';               slots = @('n','v','n') },
    @{ pattern = 'who saw the {0} {1} the {2}';          slots = @('a','n','n') }
)

$rand = New-Object System.Random

function Pick($arr) { return $arr[$rand.Next(0, $arr.Length)] }

function New-RandomQuery {
    $tpl = $Templates[$rand.Next(0, $Templates.Count)]
    $vals = @()
    foreach ($kind in $tpl.slots) {
        switch ($kind) {
            'n' { $vals += (Pick $Nouns) }
            'v' { $vals += (Pick $Verbs) }
            'p' { $vals += (Pick $Places) }
            'a' { $vals += (Pick $Adjectives) }
        }
    }
    return [string]::Format($tpl.pattern, [object[]]$vals)
}

# ---------------- Used-set persistence ----------------
$UsedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

if (Test-Path $UsedFile) {
    foreach ($line in [System.IO.File]::ReadAllLines($UsedFile)) {
        $t = $line.Trim()
        if ($t) { [void]$UsedSet.Add($t) }
    }
} else {
    New-Item -ItemType File -Path $UsedFile -Force | Out-Null
}

function Get-UnusedQuery {
    for ($i = 0; $i -lt $MaxGenerateTries; $i++) {
        $q = New-RandomQuery
        if (-not $UsedSet.Contains($q)) { return $q }
    }
    return $null
}

function Save-Used([string]$q) {
    [void]$UsedSet.Add($q)
    Add-Content -Path $UsedFile -Value $q -Encoding UTF8
}

# ---------------- Edge search ----------------
function Open-EdgeSearch([string]$query) {
    $encoded = [Uri]::EscapeDataString($query)
    $url     = "https://www.bing.com/search?q=$encoded"

    # Preferred: protocol handler opens a new tab in the running Edge window.
    try {
        Start-Process "microsoft-edge:$url" -ErrorAction Stop
        return $true
    } catch { }

    # Fallback: invoke msedge.exe directly.
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles        'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA        'Microsoft\Edge\Application\msedge.exe')
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) {
            try { Start-Process $p -ArgumentList $url -ErrorAction Stop; return $true } catch { }
        }
    }
    return $false
}

# ---------------- Main loop ----------------
Write-Host ''
Write-Host '=== Random Edge Searcher ==='
Write-Host "Memory file : $UsedFile"
Write-Host "Phrases used so far : $($UsedSet.Count)"
Write-Host "Interval    : $IntervalSeconds seconds (only fires while Edge is the active window)"
Write-Host 'Press Ctrl+C in this window to stop.'
Write-Host ''

while ($true) {
    Start-Sleep -Seconds $IntervalSeconds
    if (-not (Test-EdgeActive)) { continue }

    $q = Get-UnusedQuery
    if (-not $q) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Could not find a new phrase after $MaxGenerateTries tries; expand the word lists or templates."
        continue
    }

    if (Open-EdgeSearch $q) {
        Save-Used $q
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Searched: $q"
    } else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Failed to open Edge for: $q"
    }
}
