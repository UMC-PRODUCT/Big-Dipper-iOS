#!/usr/bin/env python3
#
#  build_template.py
#  umc-product-iOS
#
#  Created by euijjang97 on 8/31/26.
#

"""3D 명함 베이스 USDZ 템플릿 빌더 (#1246).

이 스크립트가 앵커 규약의 **진실 원천**이다. 좌표를 고치는 곳은 여기 한 곳이고,
`BusinessCardTemplate.usda` · `cardSurface.png` · `BusinessCardTemplate.usdz` 는 전부 생성물이다.
Swift 쪽 대응물은 `Features/BusinessCard/Presentation/Sources/Card3D/BusinessCardTemplate.swift`
이며, 둘이 어긋나면 `BusinessCardTemplateContractTests` 가 실패한다.

좌표계: 원점 = 카드 중심 · +Y 위 · 앞면 = +Z · `metersPerUnit = 1`(미터).
표의 값은 전부 밀리미터이고, 시안 `명함_l`(372×205pt)을 높이 기준 0.243902 mm/pt 로 환산한 것이다.

실행:
    python3 tools/card-template/build_template.py

`.usda` 생성 → `usdcat`(usdc) → `usdzip` → `usdchecker --arkit` 까지 한 번에 돈다.
`usdcat`·`usdzip`·`usdchecker` 는 macOS `/usr/bin` 에 있다 — 추가 설치가 없다.

규약 전문: `docs/claude/business-card-3d-anchor-contract.md`
"""

from __future__ import annotations

import math
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

# ──────────────────────────────────────────────────────────────
# 치수 (mm)
# ──────────────────────────────────────────────────────────────

CARD_WIDTH = 90.0
CARD_HEIGHT = 50.0
CARD_DEPTH = 0.6
CARD_CORNER_RADIUS = 8.293  # 시안 cardRadius 34pt 환산

# 카드 면(앞/뒤)이 놓이는 z. 압출 절반이라 카드 표면과 정확히 겹친다.
FACE_OFFSET = CARD_DEPTH / 2

# 사진 원판 · QR 정사각이 면에서 떠 있는 높이. z-fighting 방지.
SURFACE_LIFT = 0.05

# 시안 avatarSize 70pt 환산. 사진 원판 지름 = QR 정사각 변.
PORTRAIT_DIAMETER = 17.073
QR_CORNER_RADIUS = 1.507

# 콘텐츠 블록의 세로 중심. 시안에서 버튼 행(63pt)을 뺀 만큼을 위아래로 균등 분배한 결과다.
# 디자인팀이 "헤더 상단 고정"을 원하면 **이 한 값만** 바꾸면 전 앵커가 따라간다.
BLOCK_CENTER_Y = 0.0

# 사진 원판 · QR 정사각의 중심. 앞뒷면이 문자 그대로 같은 값이다
# (Face_Back 의 rotateY = 180 이 거울반전을 처리한다).
FACE_SURFACE_CENTER = (-32.561, -2.825 + BLOCK_CENTER_Y)

# z 층. 면(0) < 칩 캡슐(0.10) < 텍스트(0.20) < 칩 라벨(0.25) 순으로 쌓인다.
TEXT_LIFT = 0.20
CHIP_LIFT = 0.10

# 앵커는 전부 빈 Xform 이다. placeholder mesh 를 두면 합성이 지우는 것을 잊었을 때
# 유령 사각형이 카드에 남는다 — 빈 Xform 은 실패해도 아무것도 안 그린다.
#
# x = 슬롯 좌측 레이아웃 원점 · y = 텍스트 베이스라인 · z = 면에서 띄운 거리.
# `Anchor_University` · `Anchor_GenerationChip` 은 런타임에 앞 요소 폭만큼 흘러가는
# 상대 앵커라 **최악 케이스 위치**(앞 요소가 슬롯을 다 쓴 자리)를 적어 둔다 —
# 파일만 열어 본 사람이 최악을 보게 하려는 것이다.
FRONT_ANCHORS = {
    "Anchor_Name": (-20.123, 0.861 + BLOCK_CENTER_Y, TEXT_LIFT),
    "Anchor_University": (15.828, 0.861 + BLOCK_CENTER_Y, TEXT_LIFT),
    "Anchor_PartChip": (-20.123, -8.173 + BLOCK_CENTER_Y, CHIP_LIFT),
    "Anchor_GenerationChip": (-2.501, -8.173 + BLOCK_CENTER_Y, CHIP_LIFT),
}

# 링크 3줄은 **위치 앵커**다, 의미 앵커가 아니다. 시안이 값 없는 줄을 지우고 위로 당기므로
# 합성은 비어 있지 않은 링크만 순서대로 Top → Middle → Bottom 에 채운다.
# 줄 피치 6.326mm = 줄 상자 4.375 + linkSpacing 1.951.
BACK_ANCHORS = {
    "Anchor_LinkTop": (-20.123, 2.351 + BLOCK_CENTER_Y, TEXT_LIFT),
    "Anchor_LinkMiddle": (-20.123, -3.975 + BLOCK_CENTER_Y, TEXT_LIFT),
    "Anchor_LinkBottom": (-20.123, -10.301 + BLOCK_CENTER_Y, TEXT_LIFT),
}

# ──────────────────────────────────────────────────────────────
# 표면 텍스처
# ──────────────────────────────────────────────────────────────

# 시안 명함_l 의 배경 그라데이션. indigo400 → indigo500 **라이트 값**을 굽고 양 모드에서 그대로
# 쓴다 — 카드는 라이트·다크 어느 쪽에서도 인디고라 모드 적응 대상이 아니다.
# 시안은 시작 정지점에 opacity(0.8) 을 걸지만 3D 카드 뒤에는 합성할 배경이 없어 불투명으로 굽는다.
GRADIENT_START = (0x66, 0x83, 0xFF)
GRADIENT_END = (0x48, 0x69, 0xF0)
TEXTURE_SIZE = (256, 142)  # 카드 종횡비. 정지점이 둘뿐이라 이 이상 필요 없다.

# grey200 라이트 값. 아바타가 없을 때 원판에 남는 빈 자리 색이다.
PORTRAIT_PLACEHOLDER = (0xE7 / 255, 0xE8 / 255, 0xEA / 255)

CORNER_SEGMENTS = 8  # 코너당 9점 × 4 = 36점 아웃라인
DISC_SEGMENTS = 48

RESOURCES = (
    Path(__file__).resolve().parents[2]
    / "UMCApp/Features/BusinessCard/Presentation/Resources"
)
STAGE_NAME = "BusinessCardTemplate"
TEXTURE_NAME = "cardSurface.png"


# ──────────────────────────────────────────────────────────────
# 유틸
# ──────────────────────────────────────────────────────────────

def meters(value: float) -> float:
    """규약 표가 전부 mm 라 상수를 mm 로 적고 여기서 한 번만 나눈다."""
    return value / 1000.0


def fmt(value: float) -> str:
    return f"{value:.6f}"


def vec3(values) -> str:
    return "(" + ", ".join(fmt(v) for v in values) + ")"


def vec2(values) -> str:
    return "(" + ", ".join(fmt(v) for v in values) + ")"


def array(values, formatter) -> str:
    return "[" + ", ".join(formatter(v) for v in values) + "]"


# ──────────────────────────────────────────────────────────────
# 메시
# ──────────────────────────────────────────────────────────────

def rounded_rect_outline(width: float, height: float, radius: float) -> list:
    """XY 평면 둥근 사각 아웃라인을 CCW 로 돌려준다 (중심 원점, mm)."""
    half_w, half_h = width / 2, height / 2
    inner_x, inner_y = half_w - radius, half_h - radius
    corners = [
        ((inner_x, -inner_y), -90.0),
        ((inner_x, inner_y), 0.0),
        ((-inner_x, inner_y), 90.0),
        ((-inner_x, -inner_y), 180.0),
    ]
    points = []
    for (cx, cy), start in corners:
        for step in range(CORNER_SEGMENTS + 1):
            angle = math.radians(start + 90.0 * step / CORNER_SEGMENTS)
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def circle_outline(radius: float) -> list:
    return [
        (
            radius * math.cos(2 * math.pi * i / DISC_SEGMENTS),
            radius * math.sin(2 * math.pi * i / DISC_SEGMENTS),
        )
        for i in range(DISC_SEGMENTS)
    ]


def extruded_body() -> dict:
    """카드 몸통 — 둥근 사각을 두께만큼 압출한다. 앞 캡 · 뒤 캡 · 측벽."""
    outline = rounded_rect_outline(CARD_WIDTH, CARD_HEIGHT, CARD_CORNER_RADIUS)
    count = len(outline)
    front = [(x, y, CARD_DEPTH / 2) for x, y in outline]
    back = [(x, y, -CARD_DEPTH / 2) for x, y in outline]
    points = front + back

    counts = [count, count]
    indices = list(range(count)) + [count + i for i in reversed(range(count))]
    normals = [(0.0, 0.0, 1.0)] * count + [(0.0, 0.0, -1.0)] * count

    for i in range(count):
        j = (i + 1) % count
        counts.append(4)
        indices += [i, count + i, count + j, j]
        tangent = (outline[j][0] - outline[i][0], outline[j][1] - outline[i][1])
        length = math.hypot(*tangent) or 1.0
        outward = (tangent[1] / length, -tangent[0] / length, 0.0)
        normals += [outward] * 4

    # 앞뒤가 같은 텍스처를 공유한다. 시안도 앞뒤가 같은 인디고 카드다.
    uvs = [
        ((x + CARD_WIDTH / 2) / CARD_WIDTH, (y + CARD_HEIGHT / 2) / CARD_HEIGHT)
        for x, y, _ in points
    ]
    return {
        "points": [tuple(meters(v) for v in p) for p in points],
        "counts": counts,
        "indices": indices,
        "normals": normals,
        "uvs": uvs,
        "uvInterpolation": "vertex",
    }


def flat_face(outline: list, span: float) -> dict:
    """단일 n-gon 평면. `span` 은 UV 를 0…1 로 정규화할 변 길이다."""
    points = [(x, y, 0.0) for x, y in outline]
    return {
        "points": [tuple(meters(v) for v in p) for p in points],
        "counts": [len(points)],
        "indices": list(range(len(points))),
        "normals": [(0.0, 0.0, 1.0)] * len(points),
        "uvs": [(0.5 + x / span, 0.5 + y / span) for x, y in outline],
        "uvInterpolation": "vertex",
    }


# ──────────────────────────────────────────────────────────────
# PNG
# ──────────────────────────────────────────────────────────────

def write_gradient_texture(path: Path) -> None:
    width, height = TEXTURE_SIZE
    rows = []
    for row in range(height):
        pixels = bytearray()
        for column in range(width):
            # 시안은 topLeading → bottomTrailing 대각선이다. st(0,0) 이 이미지 좌하단이므로
            # 이미지 행 0 = 카드 위쪽이고, 대각 진행도는 (열 + 행) / 2 가 된다.
            ratio = (column / (width - 1) + row / (height - 1)) / 2
            pixels += bytes(
                round(start + (end - start) * ratio)
                for start, end in zip(GRADIENT_START, GRADIENT_END)
            )
        rows.append(bytes(pixels))

    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


# ──────────────────────────────────────────────────────────────
# .usda
# ──────────────────────────────────────────────────────────────

def mesh_prim(name: str, mesh: dict, material: str, indent: str, translate=None) -> str:
    xs = [p[0] for p in mesh["points"]]
    ys = [p[1] for p in mesh["points"]]
    zs = [p[2] for p in mesh["points"]]
    extent = [(min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))]

    # 함정: `prepend apiSchemas = ["MaterialBindingAPI"]` 가 없으면
    # `usdchecker --arkit` 이 MissingMaterialBindingAPI 로 떨어진다.
    lines = [
        f'{indent}def Mesh "{name}" (',
        f'{indent}    prepend apiSchemas = ["MaterialBindingAPI"]',
        f"{indent})",
        f"{indent}{{",
        f'{indent}    uniform token subdivisionScheme = "none"',
    ]
    if translate is not None:
        # 오프셋을 정점에 굽지 않고 트랜스폼으로 둔다 — 로드한 엔티티의 월드 좌표가
        # 규약 표의 값과 그대로 대응해야 계약 테스트가 z 층을 검사할 수 있다.
        lines += [
            f"{indent}    double3 xformOp:translate = "
            f"{vec3([meters(v) for v in translate])}",
            f'{indent}    uniform token[] xformOpOrder = ["xformOp:translate"]',
        ]
    lines += [
        f"{indent}    float3[] extent = {array(extent, vec3)}",
        f"{indent}    point3f[] points = {array(mesh['points'], vec3)}",
        f"{indent}    int[] faceVertexCounts = {mesh['counts']}",
        f"{indent}    int[] faceVertexIndices = {mesh['indices']}",
        f"{indent}    normal3f[] normals = {array(mesh['normals'], vec3)} (",
        f'{indent}        interpolation = "faceVarying"',
        f"{indent}    )",
        f"{indent}    texCoord2f[] primvars:st = {array(mesh['uvs'], vec2)} (",
        f'{indent}        interpolation = "{mesh["uvInterpolation"]}"',
        f"{indent}    )",
        f"{indent}    rel material:binding = "
        f"</{STAGE_NAME}/Materials/{material}>",
        f"{indent}}}",
    ]
    return "\n".join(lines)


def anchor_prim(name: str, position, indent: str) -> str:
    return "\n".join(
        [
            f'{indent}def Xform "{name}"',
            f"{indent}{{",
            f"{indent}    double3 xformOp:translate = "
            f"{vec3([meters(v) for v in position])}",
            f'{indent}    uniform token[] xformOpOrder = ["xformOp:translate"]',
            f"{indent}}}",
        ]
    )


def textured_material(name: str, texture: str) -> str:
    # 함정: `UsdPrimvarReader_float2` 의 `inputs:varname` 은 **string** 이다.
    # `token` 으로 쓰면 usdchecker 가 ShaderSdrCompliance.MismatchedPropertyType 로 떨어진다.
    return f'''    def Material "{name}"
    {{
        token outputs:surface.connect = </{STAGE_NAME}/Materials/{name}/Surface.outputs:surface>

        def Shader "Surface"
        {{
            uniform token info:id = "UsdPreviewSurface"
            color3f inputs:diffuseColor.connect = </{STAGE_NAME}/Materials/{name}/Texture.outputs:rgb>
            float inputs:metallic = 0
            float inputs:roughness = 0.65
            token outputs:surface
        }}

        def Shader "Texture"
        {{
            uniform token info:id = "UsdUVTexture"
            asset inputs:file = @{texture}@
            float2 inputs:st.connect = </{STAGE_NAME}/Materials/{name}/UVReader.outputs:result>
            token inputs:wrapS = "clamp"
            token inputs:wrapT = "clamp"
            float3 outputs:rgb
        }}

        def Shader "UVReader"
        {{
            uniform token info:id = "UsdPrimvarReader_float2"
            string inputs:varname = "st"
            float2 outputs:result
        }}
    }}'''


def flat_material(name: str, color) -> str:
    return f'''    def Material "{name}"
    {{
        token outputs:surface.connect = </{STAGE_NAME}/Materials/{name}/Surface.outputs:surface>

        def Shader "Surface"
        {{
            uniform token info:id = "UsdPreviewSurface"
            color3f inputs:diffuseColor = {vec3(color)}
            float inputs:metallic = 0
            float inputs:roughness = 0.9
            token outputs:surface
        }}
    }}'''


def build_stage() -> str:
    body = extruded_body()
    portrait = flat_face(circle_outline(PORTRAIT_DIAMETER / 2), PORTRAIT_DIAMETER)
    qr = flat_face(
        rounded_rect_outline(PORTRAIT_DIAMETER, PORTRAIT_DIAMETER, QR_CORNER_RADIUS),
        PORTRAIT_DIAMETER,
    )

    def face(
        name: str,
        sign: int,
        surface: str,
        material: str,
        mesh: dict,
        anchors: dict,
    ) -> str:
        # 함정: 뒷면 회전은 **스칼라** `double xformOp:rotateY = 180` 이어야 한다.
        # `double3 xformOp:rotateY = (0, 180, 0)` 은 usdchecker 를 통과하면서 회전이
        # 적용되지 않아 뒷면 앵커가 거울반전 없이 카드 안쪽에 박힌다 (계약 테스트 4가 잡는다).
        ops = ['"xformOp:translate"']
        rotate = ""
        if sign < 0:
            ops.append('"xformOp:rotateY"')
            rotate = "        double xformOp:rotateY = 180\n"
        center = FACE_SURFACE_CENTER
        # prim 이름과 머티리얼 이름은 **다른 것**이다. 한 인자를 양쪽에 쓰면
        # `Portrait` 처럼 둘이 어긋나는 면에서 `material:binding` 이 존재하지 않는
        # 머티리얼을 가리키고, usdchecker 는 댕글링 rel 을 에러로 보지 않아 조용히 넘어간다.
        prims = [
            mesh_prim(
                surface,
                mesh,
                material,
                "        ",
                translate=(center[0], center[1], SURFACE_LIFT),
            )
        ]
        prims += [anchor_prim(n, p, "        ") for n, p in anchors.items()]
        return (
            f'    def Xform "{name}"\n'
            f"    {{\n"
            f"        double3 xformOp:translate = "
            f"{vec3([0.0, 0.0, sign * meters(FACE_OFFSET)])}\n"
            f"{rotate}"
            f"        uniform token[] xformOpOrder = [{', '.join(ops)}]\n\n"
            + "\n\n".join(prims)
            + "\n    }"
        )

    return f'''#usda 1.0
(
    defaultPrim = "{STAGE_NAME}"
    metersPerUnit = 1
    upAxis = "Y"
)

# 생성물이다. 손으로 고치지 말고 tools/card-template/build_template.py 를 고친 뒤
# `cd UMCApp && make card-template` 을 돌린다.

def Xform "{STAGE_NAME}" (
    kind = "component"
)
{{
{mesh_prim("CardBody", body, "CardSurface", "    ")}

{face("Face_Front", 1, "Portrait", "PortraitSurface", portrait, FRONT_ANCHORS)}

{face("Face_Back", -1, "QRSurface", "QRSurface", qr, BACK_ANCHORS)}

    def Scope "Materials"
    {{
{textured_material("CardSurface", TEXTURE_NAME)}

{flat_material("PortraitSurface", PORTRAIT_PLACEHOLDER)}

{flat_material("QRSurface", (1.0, 1.0, 1.0))}
    }}
}}
'''


# ──────────────────────────────────────────────────────────────
# 파이프라인
# ──────────────────────────────────────────────────────────────

def run(command: list, cwd: Path | None = None) -> None:
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    if output:
        print(output)
    if result.returncode != 0:
        sys.exit(result.returncode)


def main() -> None:
    RESOURCES.mkdir(parents=True, exist_ok=True)
    usda = RESOURCES / f"{STAGE_NAME}.usda"
    texture = RESOURCES / TEXTURE_NAME
    usdz = RESOURCES / f"{STAGE_NAME}.usdz"

    usda.write_text(build_stage(), encoding="utf-8")
    write_gradient_texture(texture)

    # usdzip 은 넘긴 파일을 basename 으로 담는다. 텍스처 참조(@cardSurface.png@)가 패키지 안에서
    # 풀리도록 한 디렉터리에 모아 놓고 그 안에서 돈다.
    with tempfile.TemporaryDirectory() as staging:
        stage = Path(staging)
        usdc = stage / f"{STAGE_NAME}.usdc"
        shutil.copy(texture, stage / TEXTURE_NAME)
        run(["usdcat", "-o", str(usdc), str(usda)])
        run(["usdzip", f"{STAGE_NAME}.usdz", usdc.name, TEXTURE_NAME], cwd=stage)
        shutil.move(str(stage / f"{STAGE_NAME}.usdz"), usdz)

    run(["usdchecker", str(usdz), "--arkit"])
    print(f"{usdz.relative_to(RESOURCES.parents[4])} — {usdz.stat().st_size} bytes")


if __name__ == "__main__":
    main()
