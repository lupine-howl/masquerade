#!/usr/bin/env python3
"""One-shot fitter: align BodyPolygons to skeleton reference sprites in player.tscn."""

from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TSCN = ROOT / "player" / "player.tscn"

SINGLE_MAP = {
    "Head": ("Head_Sprite", "Pelvis/Abdomen/Torso/Shoulders/Neck/Head", None),
    "Torso": ("Torso", "Pelvis/Abdomen/Torso", "Torso"),
    "Jetpack": ("Jetpack", "Pelvis/Abdomen/Torso", "Torso"),
    "UpperArm_Back": ("UpperArm_Back_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back", None),
    "Forearm_Back": ("Forearm_Back_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back", None),
    "Hand_Back": ("Hand_Back_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back/Hand_Back", None),
    "UpperArm_Front": ("UpperArm_Front_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front", None),
    "Forearm_Front": ("Forearm_Front_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front", None),
    "Hand_Front": ("Hand_Front_Sprite", "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front/Hand_Front", None),
    "Thigh_Back": ("Thigh_Back_Sprite", "Pelvis/Thigh_Back", None),
    "Calf_Back": ("Calf_Back_Sprite", "Pelvis/Thigh_Back/Calf_Back", None),
    "Foot_Back": ("Foot_Sprite_Back", "Pelvis/Thigh_Back/Calf_Back/Foot_Back", None),
    "Thigh_Front": ("Thigh_Front_Sprite", "Pelvis/Thigh_Front", None),
    "Calf_Front": ("Calf_Front_Sprite", "Pelvis/Thigh_Front/Calf_Front", None),
    "Foot_Front": ("Foot_Sprite_Front", "Pelvis/Thigh_Front/Calf_Front/Foot_Front", None),
}


@dataclass
class Transform2D:
    xx: float = 1.0
    xy: float = 0.0
    yx: float = 0.0
    yy: float = 1.0
    ox: float = 0.0
    oy: float = 0.0

    @classmethod
    def identity(cls) -> "Transform2D":
        return cls()

    @classmethod
    def from_trs(cls, pos: tuple[float, float], rot: float, scale: tuple[float, float]) -> "Transform2D":
        c = math.cos(rot)
        s = math.sin(rot)
        return cls(
            c * scale[0],
            s * scale[0],
            -s * scale[1],
            c * scale[1],
            pos[0],
            pos[1],
        )

    def __matmul__(self, other: "Transform2D") -> "Transform2D":
        return Transform2D(
            self.xx * other.xx + self.yx * other.xy,
            self.xy * other.xx + self.yy * other.xy,
            self.xx * other.yx + self.yx * other.yy,
            self.xy * other.yx + self.yy * other.yy,
            self.xx * other.ox + self.yx * other.oy + self.ox,
            self.xy * other.ox + self.yy * other.oy + self.oy,
        )

    def basis_xform(self, point: tuple[float, float]) -> tuple[float, float]:
        return (
            self.xx * point[0] + self.yx * point[1],
            self.xy * point[0] + self.yy * point[1],
        )

    def xform(self, point: tuple[float, float]) -> tuple[float, float]:
        bx, by = self.basis_xform(point)
        return bx + self.ox, by + self.oy

    def affine_inverse(self) -> "Transform2D":
        det = self.xx * self.yy - self.xy * self.yx
        if abs(det) < 1e-8:
            return Transform2D.identity()
        inv_det = 1.0 / det
        ix = self.yy * inv_det
        iy = -self.xy * inv_det
        jx = -self.yx * inv_det
        jy = self.xx * inv_det
        o = self.basis_xform((-self.ox, -self.oy))
        return Transform2D(ix, iy, jx, jy, o[0], o[1])


@dataclass
class SceneNode:
    name: str
    node_type: str
    parent: str
    props: dict[str, str] = field(default_factory=dict)


NODE_RE = re.compile(
    r'^\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"',
    re.MULTILINE,
)
PROP_RE = re.compile(r"^([a-zA-Z0-9_]+) = (.+)$")


def parse_vector2(text: str) -> tuple[float, float]:
    nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?(?:e[+-]?\d+)?", text)]
    return nums[0], nums[1]


def parse_rect2(text: str) -> tuple[float, float, float, float]:
    nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?(?:e[+-]?\d+)?", text)]
    return nums[0], nums[1], nums[2], nums[3]


def parse_scene(text: str) -> dict[str, SceneNode]:
    nodes: dict[str, SceneNode] = {}
    blocks = re.split(r"(?=^\[node )", text, flags=re.MULTILINE)
    for block in blocks:
        header = block.split("\n", 1)[0]
        m = NODE_RE.match(header)
        if not m:
            continue
        name, node_type, parent = m.groups()
        path = f"{parent}/{name}" if parent != "." else name
        props: dict[str, str] = {}
        for line in block.splitlines()[1:]:
            if line.startswith("["):
                break
            pm = PROP_RE.match(line)
            if pm:
                props[pm.group(1)] = pm.group(2)
        nodes[path] = SceneNode(name, node_type, parent, props)
    return nodes


def node_local_transform(node: SceneNode) -> Transform2D:
    pos = parse_vector2(node.props.get("position", "Vector2(0, 0)"))
    rot = float(node.props.get("rotation", "0"))
    scale = parse_vector2(node.props.get("scale", "Vector2(1, 1)"))
    return Transform2D.from_trs(pos, rot, scale)


def global_transform(path: str, nodes: dict[str, SceneNode]) -> Transform2D:
    parts = path.split("/")
    xf = Transform2D.identity()
    current = []
    for part in parts:
        current.append(part)
        key = "/".join(current)
        node = nodes.get(key)
        if node is None:
            continue
        xf = xf @ node_local_transform(node)
    return xf


def sprite_rect(sprite: SceneNode) -> tuple[tuple[float, float], tuple[float, float]]:
    x, y, w, h = parse_rect2(sprite.props["region_rect"])
    offset = parse_vector2(sprite.props.get("offset", "Vector2(0, 0)"))
    scale = parse_vector2(sprite.props.get("scale", "Vector2(1, 1)"))
    flip_h = sprite.props.get("flip_h", "false") == "true"
    flip_v = sprite.props.get("flip_v", "false") == "true"

    size = (w * abs(scale[0]), h * abs(scale[1]))
    origin = offset
    rect_pos = origin
    corners = [
        rect_pos,
        (rect_pos[0] + size[0], rect_pos[1]),
        (rect_pos[0] + size[0], rect_pos[1] + size[1]),
        (rect_pos[0], rect_pos[1] + size[1]),
    ]
    if flip_h:
        corners = [
            (origin[0] + size[0] - (c[0] - origin[0]), c[1]) for c in corners
        ]
    if flip_v:
        corners = [
            (c[0], origin[1] + size[1] - (c[1] - origin[1])) for c in corners
        ]
    return corners[0], corners[2]


def sprite_fit(sprite_path: str, space_path: str, nodes: dict[str, SceneNode]) -> tuple[list[tuple[float, float]], list[tuple[float, float]]]:
    sprite = nodes[sprite_path]
    sprite_xf = global_transform(sprite_path, nodes)
    space_xf = global_transform(space_path, nodes)
    to_space = space_xf.affine_inverse() @ sprite_xf

    x, y, w, h = parse_rect2(sprite.props["region_rect"])
    _, rect_size = sprite_rect(sprite)
    rect_pos, _ = sprite_rect(sprite)
    local_corners = [
        rect_pos,
        (rect_pos[0] + abs(rect_size[0] - rect_pos[0]), rect_pos[1]),
        rect_size,
        (rect_pos[0], rect_pos[1] + abs(rect_size[1] - rect_pos[1])),
    ]
    # Use explicit rect corners from min/max of sprite_rect bounds
    min_x = min(rect_pos[0], rect_size[0])
    max_x = max(rect_pos[0], rect_size[0])
    min_y = min(rect_pos[1], rect_size[1])
    max_y = max(rect_pos[1], rect_size[1])
    local_corners = [
        (min_x, min_y),
        (max_x, min_y),
        (max_x, max_y),
        (min_x, max_y),
    ]

    polygon = [to_space.xform(p) for p in local_corners]
    uv = [
        (x, y + h),
        (x + w, y + h),
        (x + w, y),
        (x, y),
    ]
    return polygon, uv


def fmt_vector2_array(points: list[tuple[float, float]]) -> str:
    flat = ", ".join(f"{p[0]:.6g}, {p[1]:.6g}" for p in points)
    return f"PackedVector2Array({flat})"


def fmt_bones_single(bone: str) -> str:
    return f'["{bone}", PackedFloat32Array(1, 1, 1, 1)]'


def fmt_bones_abdomen() -> str:
    return (
        '["Pelvis", PackedFloat32Array(1, 1, 0, 0), '
        '"Pelvis/Abdomen", PackedFloat32Array(0, 0, 1, 1)]'
    )


def merge_abdomen(
    lower: list[tuple[float, float]],
    upper: list[tuple[float, float]],
    lower_uv: list[tuple[float, float]],
    upper_uv: list[tuple[float, float]],
) -> tuple[list[tuple[float, float]], list[tuple[float, float]]]:
    lower_mid_y = (lower[0][1] + lower[1][1]) * 0.5
    upper_mid_y = (upper[2][1] + upper[3][1]) * 0.5
    poly = [
        ((lower[0][0] + lower[1][0]) * 0.5, lower_mid_y),
        ((lower[2][0] + lower[3][0]) * 0.5, lower_mid_y),
        ((upper[2][0] + upper[3][0]) * 0.5, upper_mid_y),
        ((upper[0][0] + upper[1][0]) * 0.5, upper_mid_y),
    ]
    uv = [
        ((lower_uv[0][0] + lower_uv[1][0]) * 0.5, (lower_uv[0][1] + lower_uv[1][1]) * 0.5),
        ((lower_uv[2][0] + lower_uv[3][0]) * 0.5, (lower_uv[2][1] + lower_uv[3][1]) * 0.5),
        ((upper_uv[2][0] + upper_uv[3][0]) * 0.5, (upper_uv[2][1] + upper_uv[3][1]) * 0.5),
        ((upper_uv[0][0] + upper_uv[1][0]) * 0.5, (upper_uv[0][1] + upper_uv[1][1]) * 0.5),
    ]
    return poly, uv


def replace_polygon_block(text: str, poly_path: str, polygon: str, uv: str, bones: str) -> str:
    pattern = re.compile(
        rf'(\[node name="[^"]+" type="Polygon2D" parent="{re.escape(poly_path)}"[^\n]*\n(?:.*\n)*?)'
        r"polygon = PackedVector2Array\([^\)]*\)\n"
        r"uv = PackedVector2Array\([^\)]*\)\n"
        r'bones = \[[^\]]*\]\n',
        re.MULTILINE,
    )

    def repl(match: re.Match[str]) -> str:
        prefix = match.group(1)
        return f"{prefix}polygon = {polygon}\nuv = {uv}\nbones = {bones}\n"

    new_text, count = pattern.subn(repl, text, count=1)
    if count != 1:
        raise RuntimeError(f"Failed to update polygon at {poly_path}")
    return new_text


def main() -> None:
    text = TSCN.read_text(encoding="utf-8")
    nodes = parse_scene(text)
    space = "PlayerBody/FacingPivot/Armature/BodyPolygons"
    skeleton_prefix = "PlayerBody/FacingPivot/Armature/Skeleton2D"

    for poly_name, (sprite_name, bone, folder) in SINGLE_MAP.items():
        sprite_path = find_sprite_path(nodes, skeleton_prefix, sprite_name)
        poly_parent = (
            f"{space}/{folder}" if folder else space
        )
        poly_path = f"{poly_parent}/{poly_name}"
        polygon, uv = sprite_fit(sprite_path, space, nodes)
        text = replace_polygon_block(
            text,
            poly_path,
            fmt_vector2_array(polygon),
            fmt_vector2_array(uv),
            fmt_bones_single(bone),
        )
        print(f"Updated {poly_path}")

    lower_path = f"{skeleton_prefix}/Pelvis/LowerAbdomen_Sprite"
    upper_path = f"{skeleton_prefix}/Pelvis/Abdomen/UpperAbdomen_Sprite2"
    lower_poly, lower_uv = sprite_fit(lower_path, space, nodes)
    upper_poly, upper_uv = sprite_fit(upper_path, space, nodes)
    abdomen_poly, abdomen_uv = merge_abdomen(lower_poly, upper_poly, lower_uv, upper_uv)
    text = replace_polygon_block(
        text,
        f"{space}/AbdomenSeam",
        fmt_vector2_array(abdomen_poly),
        fmt_vector2_array(abdomen_uv),
        fmt_bones_abdomen(),
    )
    print(f"Updated {space}/AbdomenSeam")

    TSCN.write_text(text, encoding="utf-8")
    print("Done.")


def find_sprite_path(nodes: dict[str, SceneNode], skeleton_prefix: str, sprite_name: str) -> str:
    for path, node in nodes.items():
        if not path.startswith(skeleton_prefix + "/"):
            continue
        if node.node_type == "Sprite2D" and node.name == sprite_name:
            return path
    raise KeyError(sprite_name)


if __name__ == "__main__":
    main()
