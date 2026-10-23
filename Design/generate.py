"""Genereert alle SVG-bestanden van het app-icoon en het launch screen van Winter.

Draai vanuit de map Design/:   python3 generate.py
Schrijft naar AppIcon/ en LaunchScreen/. Alleen de Python-standaardbibliotheek is nodig.

Ontwerp (richting "D2 · Alles glas"): een glazen zweefvliegtuig boven glazen sneeuwheuvels,
met een glazen winterzon, in een heldere lucht. Het icoon bestaat uit losse lagen zodat
Icon Composer (Xcode 26) er echt Liquid Glass op kan zetten; de *-preview.svg bestanden
benaderen dat glas met SVG-filters en dienen als voorbeeld en als vlakke fallback.
"""
import os

# ---------------------------------------------------------------- kleuren
SKY_LIGHT = [(0, '#4FD0FF'), (1, '#3346C8')]   # standaard (Icon Composer: 2 kleuren)
SKY_DARK = [(0, '#12304D'), (1, '#04060F')]    # donker
LAUNCH_LIGHT = {'bg': '#2E86F2', 'fg': '#FFFFFF'}                 # vlak launch screen
LAUNCH_DARK = {'bg': '#0B1530', 'fg': '#CFE3FF'}

# ---------------------------------------------------------------- vormen (1024 x 1024)
def glider_path(w=34, rc=98, tc=34, span=405, tail=112):
    """Bovenaanzicht van een zweefvliegtuig: romp, lange vleugels, staartvlak."""
    f = (f"M0,-190 C{w*1.1:.1f},-186 {w*1.2:.1f},-140 {w},-80 L{w*0.45:.1f},206 "
         f"C{w*0.42:.1f},222 {-w*0.42:.1f},222 {-w*0.45:.1f},206 L{-w},-80 "
         f"C{-w*1.2:.1f},-140 {-w*1.1:.1f},-186 0,-190 Z ")
    y0, yt = -82, -70
    wing = (f"M0,{y0} L{span},{yt} Q{span+tc*0.75:.1f},{yt} {span+tc*0.7:.1f},{yt+tc*0.5:.1f} "
            f"Q{span+tc*0.6:.1f},{yt+tc} {span},{yt+tc} L0,{y0+rc} L{-span},{yt+tc} "
            f"Q{-span-tc*0.6:.1f},{yt+tc} {-span-tc*0.7:.1f},{yt+tc*0.5:.1f} Q{-span-tc*0.75:.1f},{yt} {-span},{yt} Z ")
    t = (f"M0,176 L{tail},183 Q{tail+16},186 {tail+15},197 Q{tail+14},208 {tail},208 L0,220 "
         f"L{-tail},208 Q{-tail-14},208 {-tail-15},197 Q{-tail-16},186 {-tail},183 Z")
    return f + wing + t

GLIDER = glider_path()
GLIDER_T = 'translate(470,450) rotate(14) scale(0.78)'
HILL_BACK = 'M-40,790 C190,715 360,725 540,785 C720,845 880,785 1064,750 L1064,1064 L-40,1064 Z'
HILL_FRONT = 'M-40,885 C220,825 420,835 610,885 C790,935 910,905 1064,880 L1064,1064 L-40,1064 Z'
SUN = (775, 235, 78)

# ---------------------------------------------------------------- helpers
def svg(body, defs='', w=1024, h=1024, vb='0 0 1024 1024'):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{w}" height="{h}">'
            f'<defs>{defs}</defs>{body}</svg>\n')

def gradient(gid, stops, x2='0.25'):
    s = ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="1">{s}</linearGradient>'

def glass_filter(fid, tint, opacity):
    """Benadering van Liquid Glass: doorschijnend lichaam, glans en lichtrand."""
    return (f'<filter id="{fid}" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">'
            f'<feFlood flood-color="{tint}" flood-opacity="{opacity}"/><feComposite in2="SourceAlpha" operator="in" result="body"/>'
            '<feGaussianBlur in="SourceAlpha" stdDeviation="12" result="b"/>'
            '<feSpecularLighting in="b" surfaceScale="12" specularConstant="1.5" specularExponent="16" lighting-color="#ffffff" result="s">'
            '<feDistantLight azimuth="235" elevation="48"/></feSpecularLighting>'
            '<feComposite in="s" in2="SourceAlpha" operator="in" result="sIn"/>'
            '<feColorMatrix in="sIn" type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 0.75 0" result="sSoft"/>'
            '<feMorphology in="SourceAlpha" operator="erode" radius="3" result="er"/>'
            '<feComposite in="SourceAlpha" in2="er" operator="out" result="edge"/>'
            '<feFlood flood-color="#ffffff" flood-opacity="0.9"/><feComposite in2="edge" operator="in" result="edgeW"/>'
            '<feMerge><feMergeNode in="body"/><feMergeNode in="sSoft"/><feMergeNode in="edgeW"/></feMerge></filter>')

SHADOW = ('<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">'
          '<feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#001640" flood-opacity="0.32"/></filter>')

# ---------------------------------------------------------------- lagen voor Icon Composer
LAYERS = {
    'layer-1-sun.svg': f'<circle cx="{SUN[0]}" cy="{SUN[1]}" r="{SUN[2]}" fill="#FFFFFF"/>',
    'layer-2-hill-back.svg': f'<path d="{HILL_BACK}" fill="#FFFFFF"/>',
    'layer-3-hill-front.svg': f'<path d="{HILL_FRONT}" fill="#FFFFFF"/>',
    'layer-4-glider.svg': f'<g transform="{GLIDER_T}"><path d="{GLIDER}" fill="#FFFFFF"/></g>',
}

# ---------------------------------------------------------------- volledige previews
def preview(variant):
    dark = variant == 'dark'
    tinted = variant == 'tinted'
    stops = SKY_DARK if dark else ([(0, '#2A2A2C'), (1, '#000000')] if tinted else SKY_LIGHT)
    parts = [  # (vorm, tint, dekking)
        (f'<circle cx="{SUN[0]}" cy="{SUN[1]}" r="{SUN[2]}"/>', '#E6F0FF' if dark else '#FFFFFF', 0.72 if dark else 0.60),
        (f'<path d="{HILL_BACK}"/>', '#6F9BE8' if dark else ('#FFFFFF' if tinted else '#DDF1FF'), 0.20 if dark else 0.24),
        (f'<path d="{HILL_FRONT}"/>', '#9DBDF5' if dark else '#FFFFFF', 0.26 if dark else 0.34),
        (f'<g transform="{GLIDER_T}"><path d="{GLIDER}"/></g>', '#FFFFFF', 0.60 if dark else 0.70),
    ]
    defs = gradient('sky', stops) + SHADOW
    glow_op = 0.16 if dark else (0.10 if tinted else 0.40)
    defs += (f'<radialGradient id="glow"><stop offset="0" stop-color="#FFFFFF" stop-opacity="{glow_op}"/>'
             '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>')
    body = '<rect width="1024" height="1024" fill="url(#sky)"/>'
    body += f'<circle cx="{SUN[0]}" cy="{SUN[1]}" r="210" fill="url(#glow)"/>'
    for n, (shape, tint, op) in enumerate(parts):
        defs += glass_filter(f'glass{n}', tint, op)
        body += f'<g filter="url(#shadow)"><g filter="url(#glass{n})" fill="#FFFFFF">{shape}</g></g>'
    return svg(body, defs)

# ---------------------------------------------------------------- vlak launch-merkteken
def launch_mark(colors):
    """Vlakke versie van het icoon zonder achtergrond: 320 x 280 pt, gecentreerd getoond."""
    fg = colors['fg']
    vb = '110 140 800 700'   # uitsnede rond zon, toestel en heuvels
    body = (f'<circle cx="{SUN[0]}" cy="{SUN[1]}" r="{SUN[2]}" fill="{fg}" fill-opacity="0.85"/>'
            f'<g transform="{GLIDER_T}"><path d="{GLIDER}" fill="{fg}"/></g>'
            # twee zachte heuvelbogen: achteraan halfdoorzichtig, vooraan vol
            f'<path d="M150,760 C270,690 420,680 560,740" fill="none" stroke="{fg}" stroke-opacity="0.55" '
            'stroke-width="30" stroke-linecap="round"/>'
            f'<path d="M420,800 C560,730 720,722 870,786" fill="none" stroke="{fg}" '
            'stroke-width="30" stroke-linecap="round"/>')
    return svg(body, w=320, h=280, vb=vb)

if __name__ == '__main__':
    os.makedirs('AppIcon', exist_ok=True)
    os.makedirs('LaunchScreen', exist_ok=True)
    for name, body in LAYERS.items():
        open(f'AppIcon/{name}', 'w').write(svg(body))
    for v in ('light', 'dark', 'tinted'):
        open(f'AppIcon/icon-{v}-preview.svg', 'w').write(preview(v))
    open('LaunchScreen/launch-mark.svg', 'w').write(launch_mark(LAUNCH_LIGHT))
    open('LaunchScreen/launch-mark-dark.svg', 'w').write(launch_mark(LAUNCH_DARK))
    print('Klaar: AppIcon/ en LaunchScreen/ bijgewerkt.')
