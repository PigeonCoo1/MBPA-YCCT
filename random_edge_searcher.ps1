#requires -Version 5.0
# Random Edge Searcher
# Runs random nonsense Bing searches in Microsoft Edge while Edge is the
# active (foreground) window. Phrases are persisted to used_searches.txt
# and never repeated, even across restarts.

# ---------------- Config ----------------
$MinIntervalSeconds  = 22      # min seconds between searches (randomized)
$MaxIntervalSeconds  = 38      # max seconds between searches (randomized)
$DailyCap            = 33      # stop after this many searches per calendar day
                               # (Microsoft Rewards desktop cap is ~30 searches/day,
                               #  33 leaves a small safety margin)
$MaxGenerateTries    = 2000    # how hard to try to find an unused phrase
$UseAddressBarTyping = $true   # If true, simulates Ctrl+T -> paste URL -> Enter so
                               # the search opens as a FOREGROUND tab and dwells
                               # long enough for Microsoft Rewards to count it.
                               # If false, hands the URL to msedge.exe (faster but
                               # may open as a background/throttled tab).

# ---------------- Paths -----------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$UsedFile  = Join-Path $ScriptDir 'used_searches.txt'
$StateFile = Join-Path $ScriptDir 'state.txt'

# Required for SendKeys + Clipboard.
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null

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

# ---------------- Daily counter persistence ----------------
function Get-Today { (Get-Date).ToString('yyyy-MM-dd') }

function Load-State {
    $state = @{ date = (Get-Today); count = 0 }
    if (Test-Path $StateFile) {
        try {
            $line = (Get-Content $StateFile -ErrorAction Stop | Select-Object -First 1).Trim()
            if ($line -match '^(\d{4}-\d{2}-\d{2})\|(\d+)$') {
                $state.date  = $Matches[1]
                $state.count = [int]$Matches[2]
            }
        } catch { }
    }
    if ($state.date -ne (Get-Today)) {
        $state.date  = Get-Today
        $state.count = 0
    }
    return $state
}

function Save-State($state) {
    "$($state.date)|$($state.count)" | Set-Content -Path $StateFile -Encoding UTF8
}

# ---------------- Edge search ----------------
# Resolve Edge's executable once at startup so the search call mirrors what a
# real user does (a Bing URL opened by msedge.exe, indistinguishable from
# typing into the address bar).
$Script:EdgeExe = $null
foreach ($p in @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles        'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:LOCALAPPDATA        'Microsoft\Edge\Application\msedge.exe')
)) {
    if ($p -and (Test-Path $p)) { $Script:EdgeExe = $p; break }
}

function Open-EdgeSearch([string]$query) {
    $encoded = [Uri]::EscapeDataString($query)
    # form=QBLH is the parameter Bing's own search box uses; including it makes
    # the query look like a normal in-Edge Bing search, which is what
    # Microsoft Rewards counts.
    $url = "https://www.bing.com/search?q=$encoded&form=QBLH"

    if ($UseAddressBarTyping) {
        $ok = Invoke-EdgeSearchViaAddressBar $url
        if ($ok) { return $true }
        # If SendKeys/clipboard failed (e.g. focus changed), fall through to shell.
    }
    return (Invoke-EdgeSearchViaShell $url)
}

function Invoke-EdgeSearchViaShell([string]$url) {
    if ($Script:EdgeExe) {
        try { Start-Process $Script:EdgeExe -ArgumentList $url -ErrorAction Stop; return $true } catch { }
    }
    try { Start-Process "microsoft-edge:$url" -ErrorAction Stop; return $true } catch { }
    return $false
}

function Invoke-EdgeSearchViaAddressBar([string]$url) {
    # Re-confirm Edge is still the foreground window right before sending keys.
    if (-not (Test-EdgeActive)) { return $false }

    # Stash and replace the clipboard so Ctrl+V pastes our URL.
    $hadText = $false
    $oldClip = ''
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $oldClip = [System.Windows.Forms.Clipboard]::GetText()
            $hadText = $true
        }
    } catch { }

    try { [System.Windows.Forms.Clipboard]::SetText($url) } catch { return $false }

    $sent = $false
    try {
        # Ctrl+T opens a new foreground tab. Ctrl+V pastes the URL. Enter navigates.
        [System.Windows.Forms.SendKeys]::SendWait('^t')
        Start-Sleep -Milliseconds 450
        if (Test-EdgeActive) {
            [System.Windows.Forms.SendKeys]::SendWait('^v')
            Start-Sleep -Milliseconds 250
            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
            $sent = $true
        }
    } catch { }

    # Give the paste a moment to settle, then restore the old clipboard text.
    Start-Sleep -Milliseconds 500
    try {
        if ($hadText) { [System.Windows.Forms.Clipboard]::SetText($oldClip) }
        else          { [System.Windows.Forms.Clipboard]::Clear() }
    } catch { }

    return $sent
}

# ---------------- Main loop ----------------
$state = Load-State

Write-Host ''
Write-Host '=== Random Edge Searcher ==='
Write-Host "Memory file        : $UsedFile"
Write-Host "Phrases used total : $($UsedSet.Count)"
Write-Host "Edge executable    : $(if ($Script:EdgeExe) { $Script:EdgeExe } else { '(not found - will use microsoft-edge: protocol)' })"
Write-Host "Interval           : $MinIntervalSeconds-$MaxIntervalSeconds seconds (randomized)"
Write-Host "Daily cap          : $DailyCap searches (today: $($state.count))"
Write-Host '** For Microsoft Rewards points you MUST be signed into your Microsoft account in Edge. **'
Write-Host 'Press Ctrl+C in this window to stop.'
Write-Host ''

while ($true) {
    $sleepFor = $rand.Next($MinIntervalSeconds, $MaxIntervalSeconds + 1)
    Start-Sleep -Seconds $sleepFor

    # Roll the day over if midnight passed.
    if ($state.date -ne (Get-Today)) {
        $state.date  = Get-Today
        $state.count = 0
        Save-State $state
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] New day; daily counter reset."
    }

    if ($state.count -ge $DailyCap) {
        # Cap reached - don't burn unique phrases on no-point searches.
        Start-Sleep -Seconds 60
        continue
    }

    if (-not (Test-EdgeActive)) { continue }

    $q = Get-UnusedQuery
    if (-not $q) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Could not find a new phrase after $MaxGenerateTries tries; expand the word lists or templates."
        continue
    }

    if (Open-EdgeSearch $q) {
        Save-Used $q
        $state.count++
        Save-State $state
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$($state.count)/$DailyCap today] Searched: $q"
    } else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Failed to open Edge for: $q"
    }
}
