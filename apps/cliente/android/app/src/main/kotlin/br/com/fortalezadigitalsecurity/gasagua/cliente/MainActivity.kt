package br.com.fortalezadigitalsecurity.gasagua.cliente

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        criarCanalDeAvisos()
    }

    // Canal dos avisos (Android 8 ou mais novo). O servidor manda os avisos
    // neste canal; a pessoa pode silenciar nas configurações do celular.
    private fun criarCanalDeAvisos() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val gerenciador = getSystemService(NotificationManager::class.java) ?: return
        val canal = NotificationChannel(
            "pedidos",
            "Seus pedidos",
            NotificationManager.IMPORTANCE_HIGH,
        )
        canal.description = "Andamento dos seus pedidos"
        gerenciador.createNotificationChannel(canal)
    }
}
