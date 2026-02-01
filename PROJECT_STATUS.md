# IFA AJAKO - Estado del proyecto

Fecha: 2026-02-01

## Contexto
Proyecto Flutter en `/Users/fxaleman03gmail.com/Dev/LibretaDeIFA`.
Repo GitHub: `https://github.com/fxaleman03-coder/IFA_AJAKO`.

## Últimos cambios
- Traducciones: mientras se traduce, ahora muestra el texto original (no "Translating...").
- Traducciones: el cache se carga mejor y se consulta antes de intentar traducir.
- Patakies: se agregaron **títulos** (sin contenido) para **OGBE OYECU / OGBE OYEKU** en "Historias y Patakies".
- Mapa de patakies: se agregó doble clave para asegurar coincidencia (`OGBE OYECU` y `OGBE OYEKU`).

## Archivos relevantes
- `lib/main.dart`: contiene todo el contenido, lógica de traducción y patakies.
- `lib/odu_data.dart`: lista de Odu.
- `assets/odu_content_template.json`: template.
- `tools/translation_server/server.mjs`: servidor local de traducción.

## Pendiente
- Verificar en la app que las tarjetas de OGBE OYECU / OGBE OYEKU aparecen.
- Agregar el **contenido** de cada patakí (PATAKI/TRADUCCIÓN/ENSEÑANZAS) cuando esté disponible.

## Notas
- La traducción funciona con un servidor local (`tools/translation_server`).
- Sin servidor o sin cache local, mostrará texto original y luego la traducción si existe.

