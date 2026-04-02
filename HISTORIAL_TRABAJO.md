# Historial De Trabajo

Fecha de inicio de este historial: 2026-02-14

## Contexto Del Proyecto
- Proyecto: `LibretaDeIFA` (Flutter multi-plataforma).
- App principal: `lib/main.dart`.
- Datos de Odu:
  - Lista base: `lib/odu_data.dart`
  - Modelos/repositorio: `lib/odu_models.dart`, `lib/odu_content_repository.dart`
  - Contenido: `assets/odu_content.json`
- Traduccion:
  - Cliente en app: `TranslationService` en `lib/main.dart`
  - Servidor local: `tools/translation_server/server.mjs`

## Funcionalidades Confirmadas
- Consultas:
  - Crear/editar/eliminar con undo por swipe.
  - Exportar PDF de consulta.
  - Sync con iCloud (iOS/macOS).
- Odu:
  - Navegacion por Meji/Sub-Odu.
  - Secciones expandibles con traduccion.
  - Patakies con detalle dividido por secciones.
- Suyeres:
  - Listado y pantalla de detalle.

## Observaciones Tecnicas
- `lib/main.dart` concentra mucha logica y UI (archivo muy grande).
- Existe cache local de traducciones en JSON.
- El contenido en `assets/odu_content.json` tiene 58 claves.
- Hay scripts para reconstruccion/carga desde PDFs en `tools/`.

## Mantenimiento En Curso (2026-02-14)
- Se inicio limpieza de lints y errores de `flutter analyze`.
- Se actualizo `test/widget_test.dart` para usar `LibretaIfaApp`.
- Se agrego menu en app para:
  - Sync ahora
  - Exportar JSON
  - Importar JSON

## Pendientes Recomendados
- Seguir reduciendo lints restantes en `lib/main.dart`.
- Separar `lib/main.dart` por modulos (consultas, odu, suyeres, traduccion).
- Agregar tests de unidad para:
  - Normalizacion de Odu
  - Parseo/lookup de `odu_content.json`
  - Merge de consultas + deleted IDs en sync iCloud
