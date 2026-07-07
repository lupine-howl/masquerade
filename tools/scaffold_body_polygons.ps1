param(
    [switch]$DryRun
)

# One-shot fitter: align BodyPolygons to skeleton reference sprites in player.tscn
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Tscn = Join-Path $Root 'player\player.tscn'

function Parse-Vector2($text) {
    $nums = @([regex]::Matches($text, '-?\d+(?:\.\d+)?(?:e[+-]?\d+)?') | ForEach-Object { [double]$_.Value })
    return @([double]$nums[0], [double]$nums[1])
}

function Parse-Rect2($text) {
    $nums = @([regex]::Matches($text, '-?\d+(?:\.\d+)?(?:e[+-]?\d+)?') | ForEach-Object { [double]$_.Value })
    return @([double]$nums[0], [double]$nums[1], [double]$nums[2], [double]$nums[3])
}

function New-Transform2D($xx=1, $xy=0, $yx=0, $yy=1, $ox=0, $oy=0) {
    return [PSCustomObject]@{
        xx = D $xx
        xy = D $xy
        yx = D $yx
        yy = D $yy
        ox = D $ox
        oy = D $oy
    }
}

function Transform-FromTRS($pos, $rot, $scale) {
    $c = [Math]::Cos($rot)
    $s = [Math]::Sin($rot)
    return New-Transform2D ($c * $scale[0]) ($s * $scale[0]) (-$s * $scale[1]) ($c * $scale[1]) $pos[0] $pos[1]
}

function Multiply-Transform2D($a, $b) {
    $axx = D $a.xx; $axy = D $a.xy; $ayx = D $a.yx; $ayy = D $a.yy; $aox = D $a.ox; $aoy = D $a.oy
    $bxx = D $b.xx; $bxy = D $b.xy; $byx = D $b.yx; $byy = D $b.yy; $box = D $b.ox; $boy = D $b.oy
    return New-Transform2D `
        ($axx * $bxx + $ayx * $bxy) `
        ($axy * $bxx + $ayy * $bxy) `
        ($axx * $byx + $ayx * $byy) `
        ($axy * $byx + $ayy * $byy) `
        ($axx * $box + $ayx * $boy + $aox) `
        ($axy * $box + $ayy * $boy + $aoy)
}

function D([object]$v) {
    if ($v -is [array]) { return [double]$v[0] }
    return [double]$v
}

function Xform-Point($t, $px, $py) {
    $px = D $px
    $py = D $py
    $xx = D $t.xx; $xy = D $t.xy; $yx = D $t.yx; $yy = D $t.yy; $ox = D $t.ox; $oy = D $t.oy
    $out = New-Object 'double[]' 2
    $out[0] = $xx * $px + $yx * $py + $ox
    $out[1] = $xy * $px + $yy * $py + $oy
    return $out
}

function Inverse-Transform2D($t) {
    $det = [double]$t.xx * [double]$t.yy - [double]$t.xy * [double]$t.yx
    if ([Math]::Abs($det) -lt 1e-8) { return New-Transform2D }
    $inv = 1.0 / $det
    $ix = [double]$t.yy * $inv; $iy = -[double]$t.xy * $inv; $jx = -[double]$t.yx * $inv; $jy = [double]$t.xx * $inv
    $ox = [double]$t.ox; $oy = [double]$t.oy
    $bx = [double]($t.xx * (-$ox) + $t.yx * (-$oy))
    $by = [double]($t.xy * (-$ox) + $t.yy * (-$oy))
    return New-Transform2D $ix $iy $jx $jy $bx $by
}

function Parse-Nodes($text) {
    $nodes = @{}
    $blocks = [regex]::Split($text, '(?=^\[node )', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($block in $blocks) {
        if ($block -notmatch '^\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"') { continue }
        $name = $Matches[1]; $type = $Matches[2]; $parent = $Matches[3]
        $path = if ($parent -eq '.') { $name } else { "$parent/$name" }
        $props = @{}
        foreach ($line in ($block -split "`n")) {
            if ($line -match '^([A-Za-z0-9_]+) = (.+)$') { $props[$Matches[1]] = $Matches[2] }
        }
        $nodes[$path] = [PSCustomObject]@{ Name=$name; Type=$type; Parent=$parent; Props=$props }
    }
    return $nodes
}

function Get-Prop($props, $key, $default) {
    if ($props.ContainsKey($key)) { return $props[$key] }
    return $default
}

function Get-LocalTransform($node) {
    $pos = Parse-Vector2 (Get-Prop $node.Props 'position' 'Vector2(0, 0)')
    $rot = [double](Get-Prop $node.Props 'rotation' '0')
    $scale = Parse-Vector2 (Get-Prop $node.Props 'scale' 'Vector2(1, 1)')
    return Transform-FromTRS $pos $rot $scale
}

function Get-GlobalTransform($path, $nodes) {
    $xf = New-Transform2D
    $parts = $path -split '/'
    $current = @()
    foreach ($part in $parts) {
        $current += $part
        $key = $current -join '/'
        if (-not $nodes.ContainsKey($key)) { continue }
        $xf = Multiply-Transform2D $xf (Get-LocalTransform $nodes[$key])
    }
    return $xf
}

function Get-SpriteCorners($sprite) {
    $rect = Parse-Rect2 $sprite.Props['region_rect']
    $rx = [double]$rect[0]; $ry = [double]$rect[1]; $rw = [double]$rect[2]; $rh = [double]$rect[3]
    $offset = Parse-Vector2 (Get-Prop $sprite.Props 'offset' 'Vector2(0, 0)')
    $scale = Parse-Vector2 (Get-Prop $sprite.Props 'scale' 'Vector2(1, 1)')
    $flipH = ((Get-Prop $sprite.Props 'flip_h' 'false') -eq 'true')
    $flipV = ((Get-Prop $sprite.Props 'flip_v' 'false') -eq 'true')
    $sizeX = $rw * [Math]::Abs([double]$scale[0])
    $sizeY = $rh * [Math]::Abs([double]$scale[1])
    $minX = [double]$offset[0]; $minY = [double]$offset[1]
    $maxX = $minX + $sizeX; $maxY = $minY + $sizeY
    if ($flipH) { $tmp = $minX; $minX = [double]$offset[0] + $sizeX - ($maxX - [double]$offset[0]); $maxX = [double]$offset[0] + $sizeX - ($tmp - [double]$offset[0]) }
    if ($flipV) { $tmp = $minY; $minY = [double]$offset[1] + $sizeY - ($maxY - [double]$offset[1]); $maxY = [double]$offset[1] + $sizeY - ($tmp - [double]$offset[1]) }
    $c0 = New-Object double[] 2; $c0[0] = $minX; $c0[1] = $minY
    $c1 = New-Object double[] 2; $c1[0] = $maxX; $c1[1] = $minY
    $c2 = New-Object double[] 2; $c2[0] = $maxX; $c2[1] = $maxY
    $c3 = New-Object double[] 2; $c3[0] = $minX; $c3[1] = $maxY
    return @{
        corners = @($c0, $c1, $c2, $c3)
        rect = @($rx, $ry, $rw, $rh)
    }
}

function Get-SpriteFit($spritePath, $spacePath, $nodes) {
    $sprite = $nodes[$spritePath]
    $spriteXf = Get-GlobalTransform $spritePath $nodes
    $spaceXf = Get-GlobalTransform $spacePath $nodes
    $toSpace = Multiply-Transform2D (Inverse-Transform2D $spaceXf) $spriteXf
    $cornerData = Get-SpriteCorners $sprite
    $corners = $cornerData.corners
    $rect = $cornerData.rect
    $polygon = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $corners) {
        $polygon.Add((Xform-Point $toSpace (D $c[0]) (D $c[1])))
    }
    $rx = D $rect[0]; $ry = D $rect[1]; $rw = D $rect[2]; $rh = D $rect[3]
    $uv0 = New-Object double[] 2; $uv0[0] = $rx; $uv0[1] = $ry + $rh
    $uv1 = New-Object double[] 2; $uv1[0] = $rx + $rw; $uv1[1] = $ry + $rh
    $uv2 = New-Object double[] 2; $uv2[0] = $rx + $rw; $uv2[1] = $ry
    $uv3 = New-Object double[] 2; $uv3[0] = $rx; $uv3[1] = $ry
    $uv = @($uv0, $uv1, $uv2, $uv3)
    return @{ polygon = $polygon; uv = $uv }
}

function Format-Vector2Array($points) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($pt in $points) {
        $parts.Add(('{0:g}, {1:g}' -f (D $pt[0]), (D $pt[1])))
    }
    return 'PackedVector2Array(' + ($parts -join ', ') + ')'
}

function Replace-PolygonBlock($text, $polyName, $polyParent, $polygon, $uv, $bones) {
    $escapedParent = [regex]::Escape($polyParent)
    $escapedName = [regex]::Escape($polyName)
    $pattern = "(?ms)(\[node name=`"$escapedName`" type=`"Polygon2D`" parent=`"$escapedParent`"[^\n]*\r?\n.*?)polygon = PackedVector2Array\([^\)]*\)\r?\nuv = PackedVector2Array\([^\)]*\)\r?\nbones = [^\r\n]*\r?\n"
    $replacement = "`${1}polygon = $polygon`nuv = $uv`nbones = $bones`n"
    $newText = [regex]::Replace($text, $pattern, $replacement, 1)
    if ($newText -eq $text) { throw "Failed to update polygon $polyName under $polyParent" }
    return $newText
}

function Find-SpritePath($nodes, $prefix, $spriteName) {
    foreach ($entry in $nodes.GetEnumerator()) {
        if ($entry.Key.StartsWith("$prefix/") -and $entry.Value.Type -eq 'Sprite2D' -and $entry.Value.Name -eq $spriteName) {
            return $entry.Key
        }
    }
    throw "Sprite not found: $spriteName"
}

$singleMap = [ordered]@{
    'Head' = @('Head_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/Neck/Head', $null)
    'Torso' = @('Torso', 'Pelvis/Abdomen/Torso', 'Torso')
    'Jetpack' = @('Jetpack', 'Pelvis/Abdomen/Torso', 'Torso')
    'UpperArm_Back' = @('UpperArm_Back_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back', $null)
    'Forearm_Back' = @('Forearm_Back_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back', $null)
    'Hand_Back' = @('Hand_Back_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back/Hand_Back', $null)
    'UpperArm_Front' = @('UpperArm_Front_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front', $null)
    'Forearm_Front' = @('Forearm_Front_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front', $null)
    'Hand_Front' = @('Hand_Front_Sprite', 'Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front/Hand_Front', $null)
    'Thigh_Back' = @('Thigh_Back_Sprite', 'Pelvis/Thigh_Back', $null)
    'Calf_Back' = @('Calf_Back_Sprite', 'Pelvis/Thigh_Back/Calf_Back', $null)
    'Foot_Back' = @('Foot_Sprite_Back', 'Pelvis/Thigh_Back/Calf_Back/Foot_Back', $null)
    'Thigh_Front' = @('Thigh_Front_Sprite', 'Pelvis/Thigh_Front', $null)
    'Calf_Front' = @('Calf_Front_Sprite', 'Pelvis/Thigh_Front/Calf_Front', $null)
    'Foot_Front' = @('Foot_Sprite_Front', 'Pelvis/Thigh_Front/Calf_Front/Foot_Front', $null)
}

$text = Get-Content -Raw -LiteralPath $Tscn
$nodes = Parse-Nodes $text
$space = 'PlayerBody/FacingPivot/Armature/BodyPolygons'
$skeletonPrefix = 'PlayerBody/FacingPivot/Armature/Skeleton2D'

foreach ($entry in $singleMap.GetEnumerator()) {
    $polyName = $entry.Key
    $spriteName, $bone, $folder = $entry.Value
    $spritePath = Find-SpritePath $nodes $skeletonPrefix $spriteName
    $polyParent = if ($folder) { "$space/$folder" } else { $space }
    $polyPath = "$polyParent/$polyName"
    $fit = Get-SpriteFit $spritePath $space $nodes
    $polygon = $fit.polygon
    $uv = $fit.uv
    $bones = "[`"$bone`", PackedFloat32Array(1, 1, 1, 1)]"
    $text = Replace-PolygonBlock $text $polyName $polyParent (Format-Vector2Array $polygon) (Format-Vector2Array $uv) $bones
    Write-Host "Updated $polyPath"
}

$lowerPath = "$skeletonPrefix/Pelvis/LowerAbdomen_Sprite"
$upperPath = "$skeletonPrefix/Pelvis/Abdomen/UpperAbdomen_Sprite2"
$lowerFit = Get-SpriteFit $lowerPath $space $nodes
$upperFit = Get-SpriteFit $upperPath $space $nodes
$lowerPoly = $lowerFit.polygon
$lowerUv = $lowerFit.uv
$upperPoly = $upperFit.polygon
$upperUv = $upperFit.uv
$lowerMidY = ($lowerPoly[0][1] + $lowerPoly[1][1]) / 2.0
$upperMidY = ($upperPoly[2][1] + $upperPoly[3][1]) / 2.0
$abdomenPoly = @(
    @((($lowerPoly[0][0] + $lowerPoly[1][0]) / 2.0), $lowerMidY),
    @((($lowerPoly[2][0] + $lowerPoly[3][0]) / 2.0), $lowerMidY),
    @((($upperPoly[2][0] + $upperPoly[3][0]) / 2.0), $upperMidY),
    @((($upperPoly[0][0] + $upperPoly[1][0]) / 2.0), $upperMidY)
)
$abdomenUv = @(
    @((($lowerUv[0][0] + $lowerUv[1][0]) / 2.0), (($lowerUv[0][1] + $lowerUv[1][1]) / 2.0)),
    @((($lowerUv[2][0] + $lowerUv[3][0]) / 2.0), (($lowerUv[2][1] + $lowerUv[3][1]) / 2.0)),
    @((($upperUv[2][0] + $upperUv[3][0]) / 2.0), (($upperUv[2][1] + $upperUv[3][1]) / 2.0)),
    @((($upperUv[0][0] + $upperUv[1][0]) / 2.0), (($upperUv[0][1] + $upperUv[1][1]) / 2.0))
)
$abdomenBones = '["Pelvis", PackedFloat32Array(1, 1, 0, 0), "Pelvis/Abdomen", PackedFloat32Array(0, 0, 1, 1)]'
$text = Replace-PolygonBlock $text 'AbdomenSeam' $space (Format-Vector2Array $abdomenPoly) (Format-Vector2Array $abdomenUv) $abdomenBones
Write-Host "Updated $space/AbdomenSeam"

if ($DryRun) {
    Write-Host 'Dry run only; scene not saved.'
    return
}

Set-Content -LiteralPath $Tscn -Value $text -NoNewline -Encoding utf8
Write-Host 'Done.'
