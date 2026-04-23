$ErrorActionPreference = "Continue"
$base = "http://localhost:4000"
$hAdmin = @{"x-role"="admin"}

"TEST7_POST_VACUNAS_APLICAR_START"
$body7 = @{mascota_id=1;vacuna_id=2;veterinario_id=1;costo_cobrado=480} | ConvertTo-Json -Compress
try {
  $r7 = Invoke-RestMethod -Method Post -Uri "$base/vacunas/aplicar" -Headers $hAdmin -ContentType "application/json" -Body $body7 -TimeoutSec 20
  "test7_post_ok=true"
  "test7_post_response=$($r7 | ConvertTo-Json -Compress)"
} catch {
  "test7_post_ok=false"
  "test7_post_error=$($_.Exception.Message)"
  if ($_.ErrorDetails.Message) { "test7_post_error_details=$($_.ErrorDetails.Message)" }
}
try {
  $r7g = Invoke-RestMethod -Method Get -Uri "$base/vacunacion-pendiente" -Headers $hAdmin -TimeoutSec 20
  "test7_get_ok=true"
  "test7_after_cache=$($r7g.cache)"
  "test7_after_count=$($r7g.data.Count)"
} catch {
  "test7_get_ok=false"
  "test7_get_error=$($_.Exception.Message)"
  if ($_.ErrorDetails.Message) { "test7_get_error_details=$($_.ErrorDetails.Message)" }
}
"TEST7_POST_VACUNAS_APLICAR_END"

"TEST8_POST_CITAS_AGENDAR_START"
$body8 = @{mascota_id=1;veterinario_id=1;fecha_hora="2026-05-01T10:00";motivo="Control"} | ConvertTo-Json -Compress
try {
  $r8 = Invoke-RestMethod -Method Post -Uri "$base/citas/agendar" -Headers $hAdmin -ContentType "application/json" -Body $body8 -TimeoutSec 20
  "test8_ok=true"
  "test8_response=$($r8 | ConvertTo-Json -Compress)"
} catch {
  "test8_ok=false"
  "test8_error=$($_.Exception.Message)"
  if ($_.ErrorDetails.Message) { "test8_error_details=$($_.ErrorDetails.Message)" }
}
"TEST8_POST_CITAS_AGENDAR_END"

"TEST9_SQL_DIRECTO_START"
$env:PGPASSWORD = $env:APP_VET_PASSWORD
"app_vet_password_set=$([string]::IsNullOrEmpty($env:APP_VET_PASSWORD) -eq $false)"
"--9a--"
psql -h localhost -U app_vet -d clinica_vet -c "SELECT COUNT(*) AS sin_contexto FROM mascotas;"
"exit_9a=$LASTEXITCODE"
"--9b--"
psql -h localhost -U app_vet -d clinica_vet -c "SET app.current_vet_id='1'; SELECT COUNT(*) AS con_contexto FROM mascotas; SELECT array_agg(nombre ORDER BY id) AS nombres FROM mascotas;"
"exit_9b=$LASTEXITCODE"
"--9c--"
psql -h localhost -U app_vet -d clinica_vet -c "SELECT COUNT(*) FROM duenos;"
"exit_9c=$LASTEXITCODE"
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
"TEST9_SQL_DIRECTO_END"

"TEST10_DOCKER_LOGS_API_START"
docker compose logs api --tail 120
"exit_10=$LASTEXITCODE"
"TEST10_DOCKER_LOGS_API_END"
