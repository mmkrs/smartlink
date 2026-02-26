$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$SharedCommandsDir = Join-Path $Root "pack/shared/commands"
$SharedAgentsDir = Join-Path $Root "pack/shared/agents"

function Quote-Yaml {
    param([string]$Value)

    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Test-RawYamlValue {
    param([string]$Value)

    if ($null -eq $Value) {
        return $false
    }

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(true|false|null)$') {
        return $true
    }
    if ($trimmed -match '^-?[0-9]+(\.[0-9]+)?$') {
        return $true
    }
    if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
        $inner = $trimmed.Substring(1, $trimmed.Length - 2)
        if (
            $inner.Contains(",") -or
            $inner.Contains(":") -or
            $inner.Contains('"') -or
            $inner.Contains("'") -or
            $inner.Contains("{") -or
            $inner.Contains("[")
        ) {
            return $true
        }
    }

    if ($trimmed.StartsWith("{") -and $trimmed.EndsWith("}")) {
        $inner = $trimmed.Substring(1, $trimmed.Length - 2)
        if ($inner.Contains(":")) {
            return $true
        }
    }

    return $false
}

function Parse-CanonicalDoc {
    param([string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    $raw = $raw -replace "`r`n", "`n"

    $match = [regex]::Match($raw, '(?s)^---\n(.*?)\n---\n?(.*)$')
    if (-not $match.Success) {
        throw "${Path}: missing or invalid frontmatter"
    }

    $frontmatter = $match.Groups[1].Value
    $body = $match.Groups[2].Value.TrimEnd("`n")
    if ([string]::IsNullOrWhiteSpace($body)) {
        throw "${Path}: empty body"
    }

    $metadata = [ordered]@{}
    foreach ($line in ($frontmatter -split "`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        $fmMatch = [regex]::Match($line, '^\s*([^:]+)\s*:\s*(.*)\s*$')
        if (-not $fmMatch.Success) {
            throw "${Path}: invalid frontmatter line: $line"
        }

        $key = $fmMatch.Groups[1].Value.Trim()
        $value = $fmMatch.Groups[2].Value.Trim()

        if ($value.Length -ge 2) {
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        $metadata[$key] = $value
    }

    $name = if ($metadata.Contains("name") -and -not [string]::IsNullOrWhiteSpace($metadata["name"])) {
        $metadata["name"]
    }
    else {
        [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }

    $description = if ($metadata.Contains("description")) { $metadata["description"] } else { "" }
    $argumentHint = if ($metadata.Contains("argument-hint")) { $metadata["argument-hint"] } else { $null }

    if ([string]::IsNullOrWhiteSpace($description)) {
        throw "${Path}: missing description"
    }

    return [pscustomobject]@{
        Name = $name
        Description = $description
        ArgumentHint = $argumentHint
        Body = "$body`n"
        Metadata = $metadata
        Source = $Path
    }
}

function Resolve-AgentValue {
    param(
        [System.Collections.IDictionary]$Metadata,
        [string]$Tool,
        [string]$Field
    )

    $toolKey = "$Tool.$Field"
    if ($Metadata.Contains($toolKey)) {
        return [string]$Metadata[$toolKey]
    }

    $commonKey = "common.$Field"
    if ($Metadata.Contains($commonKey)) {
        return [string]$Metadata[$commonKey]
    }

    return $null
}

function Add-OptionalEntry {
    param(
        [ref]$Entries,
        [string]$Key,
        [string]$Value,
        [switch]$Raw
    )

    if ($null -eq $Value -or $Value -eq "") {
        return
    }

    $entry = @{ Key = $Key; Value = $Value }

    if ($Raw.IsPresent -or (Test-RawYamlValue -Value $Value)) {
        $entry.Raw = $true
    }

    $Entries.Value += $entry
}

function Add-ExtraEntries {
    param(
        [ref]$Entries,
        [System.Collections.IDictionary]$Metadata,
        [string]$Prefix
    )

    foreach ($key in $Metadata.Keys) {
        if ($key.StartsWith($Prefix, [System.StringComparison]::Ordinal)) {
            $field = $key.Substring($Prefix.Length)
            Add-OptionalEntry -Entries ([ref]$Entries.Value) -Key $field -Value ([string]$Metadata[$key])
        }
    }
}

function Build-Frontmatter {
    param([array]$Entries)

    $lines = @("---")
    foreach ($entry in $Entries) {
        if ($null -eq $entry.Value) {
            continue
        }

        if ($entry.ContainsKey("Raw") -and $entry.Raw) {
            $lines += "$($entry.Key): $($entry.Value)"
        }
        else {
            $lines += "$($entry.Key): $(Quote-Yaml ([string]$entry.Value))"
        }
    }
    $lines += "---"
    return ($lines -join "`n")
}

function With-Frontmatter {
    param(
        [array]$Entries,
        [string]$Body
    )

    $frontmatter = Build-Frontmatter -Entries $Entries
    return "$frontmatter`n`n$($Body.TrimEnd("`n"))`n"
}

function Write-IfChanged {
    param(
        [string]$Path,
        [string]$Content,
        [string]$RootPath,
        [ref]$Written,
        [ref]$Unchanged,
        [ref]$Total
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $status = "write"
    if (Test-Path -LiteralPath $Path) {
        $existing = [System.IO.File]::ReadAllText($Path)
        $existing = $existing -replace "`r`n", "`n"
        if ($existing -ceq $Content) {
            $status = "ok"
        }
    }

    if ($status -eq "write") {
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
        $Written.Value++
    }
    else {
        $Unchanged.Value++
    }
    $Total.Value++

    $rel = $Path
    if ($Path.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $Path.Substring($RootPath.Length).TrimStart([char]'\', [char]'/')
    }
    Write-Host ("{0,-5} {1}" -f $status, $rel)
}

$commandFiles = @()
if (Test-Path -LiteralPath $SharedCommandsDir) {
    $commandFiles = Get-ChildItem -LiteralPath $SharedCommandsDir -Filter "*.md" -File | Sort-Object Name
}

$agentFiles = @()
if (Test-Path -LiteralPath $SharedAgentsDir) {
    $agentFiles = Get-ChildItem -LiteralPath $SharedAgentsDir -Filter "*.md" -File | Sort-Object Name
}

if ($commandFiles.Count -eq 0 -and $agentFiles.Count -eq 0) {
    Write-Error "Nothing to generate. Add canonical files in pack/shared/commands and pack/shared/agents."
    exit 1
}

$outputs = New-Object System.Collections.Generic.List[object]

foreach ($file in $commandFiles) {
    $doc = Parse-CanonicalDoc -Path $file.FullName

    $meta = $doc.Metadata

    # Claude Code command/skill frontmatter
    $claudeEntries = @(
        @{ Key = "name"; Value = $doc.Name },
        @{ Key = "description"; Value = $doc.Description }
    )

    $claudeArgHint = Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "argument-hint"
    if ([string]::IsNullOrWhiteSpace($claudeArgHint)) {
        $claudeArgHint = $doc.ArgumentHint
    }
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "argument-hint" -Value $claudeArgHint

    $claudeDisableModelInvocation = Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "disable-model-invocation"
    if ([string]::IsNullOrWhiteSpace($claudeDisableModelInvocation)) {
        $claudeDisableModelInvocation = "true"
    }
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "disable-model-invocation" -Value $claudeDisableModelInvocation

    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "user-invocable" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "user-invocable")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "allowed-tools" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "allowed-tools")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "model")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "context" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "context")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "agent" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "agent")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "hooks" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "hooks")
    Add-ExtraEntries -Entries ([ref]$claudeEntries) -Metadata $meta -Prefix "claude.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".claude/commands/$($doc.Name).md"
            Content = With-Frontmatter -Entries $claudeEntries -Body $doc.Body
        })

    # Cursor command files are markdown-only
    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".cursor/commands/$($doc.Name).md"
            Content = "$($doc.Body.TrimEnd("`n"))`n"
        })

    # OpenCode command frontmatter
    $openCodeCommandEntries = @(
        @{ Key = "description"; Value = $doc.Description }
    )
    Add-OptionalEntry -Entries ([ref]$openCodeCommandEntries) -Key "agent" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "agent")
    Add-OptionalEntry -Entries ([ref]$openCodeCommandEntries) -Key "subtask" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "subtask")
    Add-OptionalEntry -Entries ([ref]$openCodeCommandEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "model")
    Add-ExtraEntries -Entries ([ref]$openCodeCommandEntries) -Metadata $meta -Prefix "opencode.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".opencode/commands/$($doc.Name).md"
            Content = With-Frontmatter -Entries $openCodeCommandEntries -Body $doc.Body
        })

    # VS Code prompt file frontmatter
    $vsCodePromptEntries = @(
        @{ Key = "name"; Value = $doc.Name },
        @{ Key = "description"; Value = $doc.Description }
    )

    $vsCodeArgHint = Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "argument-hint"
    if ([string]::IsNullOrWhiteSpace($vsCodeArgHint)) {
        $vsCodeArgHint = $doc.ArgumentHint
    }
    Add-OptionalEntry -Entries ([ref]$vsCodePromptEntries) -Key "argument-hint" -Value $vsCodeArgHint

    $vsCodeAgent = Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "agent"
    if ([string]::IsNullOrWhiteSpace($vsCodeAgent)) {
        $vsCodeAgent = "agent"
    }
    Add-OptionalEntry -Entries ([ref]$vsCodePromptEntries) -Key "agent" -Value $vsCodeAgent

    Add-OptionalEntry -Entries ([ref]$vsCodePromptEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "model")
    Add-OptionalEntry -Entries ([ref]$vsCodePromptEntries) -Key "tools" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "tools")
    Add-ExtraEntries -Entries ([ref]$vsCodePromptEntries) -Metadata $meta -Prefix "vscode.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".github/prompts/$($doc.Name).prompt.md"
            Content = With-Frontmatter -Entries $vsCodePromptEntries -Body $doc.Body
        })
}

foreach ($file in $agentFiles) {
    $doc = Parse-CanonicalDoc -Path $file.FullName
    $meta = $doc.Metadata

    # Claude Code
    $claudeEntries = @(
        @{ Key = "name"; Value = $doc.Name },
        @{ Key = "description"; Value = $doc.Description }
    )
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "tools" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "tools")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "disallowedTools" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "disallowedTools")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "model")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "permissionMode" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "permissionMode")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "maxTurns" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "maxTurns")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "mcpServers" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "mcpServers")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "hooks" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "hooks")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "memory" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "memory")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "background" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "background")
    Add-OptionalEntry -Entries ([ref]$claudeEntries) -Key "isolation" -Value (Resolve-AgentValue -Metadata $meta -Tool "claude" -Field "isolation")
    Add-ExtraEntries -Entries ([ref]$claudeEntries) -Metadata $meta -Prefix "claude.extra."

    $agentBodyContent = With-Frontmatter -Entries $claudeEntries -Body $doc.Body
    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".claude/agents/$($doc.Name).md"
            Content = $agentBodyContent
        })

    # Cursor
    $cursorEntries = @(
        @{ Key = "name"; Value = $doc.Name },
        @{ Key = "description"; Value = $doc.Description }
    )
    Add-OptionalEntry -Entries ([ref]$cursorEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "cursor" -Field "model")
    Add-OptionalEntry -Entries ([ref]$cursorEntries) -Key "readonly" -Value (Resolve-AgentValue -Metadata $meta -Tool "cursor" -Field "readonly")
    Add-OptionalEntry -Entries ([ref]$cursorEntries) -Key "is_background" -Value (Resolve-AgentValue -Metadata $meta -Tool "cursor" -Field "is_background")
    Add-ExtraEntries -Entries ([ref]$cursorEntries) -Metadata $meta -Prefix "cursor.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".cursor/agents/$($doc.Name).md"
            Content = With-Frontmatter -Entries $cursorEntries -Body $doc.Body
        })

    # OpenCode
    $openCodeEntries = @(
        @{ Key = "description"; Value = $doc.Description }
    )

    $opMode = Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "mode"
    if ([string]::IsNullOrWhiteSpace($opMode)) {
        $opMode = "subagent"
    }

    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "mode" -Value $opMode
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "model")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "temperature" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "temperature")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "steps" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "steps")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "disable" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "disable")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "tools" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "tools")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "permission" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "permission")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "hidden" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "hidden")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "color" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "color")
    Add-OptionalEntry -Entries ([ref]$openCodeEntries) -Key "top_p" -Value (Resolve-AgentValue -Metadata $meta -Tool "opencode" -Field "top_p")
    Add-ExtraEntries -Entries ([ref]$openCodeEntries) -Metadata $meta -Prefix "opencode.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".opencode/agents/$($doc.Name).md"
            Content = With-Frontmatter -Entries $openCodeEntries -Body $doc.Body
        })

    # VS Code Copilot
    $vsCodeEntries = @(
        @{ Key = "name"; Value = $doc.Name },
        @{ Key = "description"; Value = $doc.Description }
    )

    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "argument-hint" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "argument-hint")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "tools" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "tools")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "agents" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "agents")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "model" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "model")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "user-invokable" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "user-invokable")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "disable-model-invocation" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "disable-model-invocation")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "target" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "target")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "mcp-servers" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "mcp-servers")
    Add-OptionalEntry -Entries ([ref]$vsCodeEntries) -Key "handoffs" -Value (Resolve-AgentValue -Metadata $meta -Tool "vscode" -Field "handoffs")
    Add-ExtraEntries -Entries ([ref]$vsCodeEntries) -Metadata $meta -Prefix "vscode.extra."

    $outputs.Add([pscustomobject]@{
            Path = Join-Path $Root ".github/agents/$($doc.Name).agent.md"
            Content = With-Frontmatter -Entries $vsCodeEntries -Body $doc.Body
        })
}

$written = 0
$unchanged = 0
$total = 0

foreach ($output in ($outputs | Sort-Object Path)) {
    Write-IfChanged -Path $output.Path -Content $output.Content -RootPath $Root -Written ([ref]$written) -Unchanged ([ref]$unchanged) -Total ([ref]$total)
}

Write-Host ""
Write-Host "Generated files: $total"
Write-Host "- written: $written"
Write-Host "- unchanged: $unchanged"
Write-Host ""
Write-Host "Isolation report:"
Write-Host "- OpenCode reads .opencode/commands and .opencode/agents."
Write-Host "- Claude Code reads .claude/commands and .claude/agents."
Write-Host "- Cursor reads .cursor/commands and .cursor/agents (and may also read .claude/agents for compatibility)."
Write-Host "- VS Code Copilot reads .github/prompts and .github/agents (and may also read .claude/agents for compatibility)."
Write-Host "- Potentially shared files (.claude/.cursor/.github) are generated from the same canonical source."
