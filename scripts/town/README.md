# Meadow presentation

Meadow Preview remains the single playable entry scene. Its saved WorldEnvironment uses color ambient lighting; sky ambient lighting had no configured sky and produced black shaded surfaces. Sun shadow opacity is 0.6.

ReferencePresentation applies scene-local material overrides to existing oak/plant textures and the legacy roof texture. Nearest filtering, alpha-cut foliage, original mesh geometry, and collision are retained. It also applies to nature props purchased during play. This is a presentation correction, not a replacement asset library.

OceanBackdrop is a static visual ocean below the walking surface. It prevents an empty background showing beyond the finite imported coastal mesh. It has no walking collision. The actual shore, beach, and pier remain part of the district layout.

The separate Design Meadow restaurant scene task is assembling the approved expansion kit through tools/meadow/assemble_expansion.gd. Do not run a second district generator over those changes. Visual comparison still shows proportions, layered planting, and shoreline-detail gaps versus the reference; this pass does not claim a completed art match.
