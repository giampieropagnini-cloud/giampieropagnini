# Prove sul driver Demo: la simulazione deve comportarsi come una
# telecamera vera (scatti, registrazioni, memoria, errori sensati).

import pathlib
import sys
import time
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.drivers.base import ErroreTelecamera   # noqa: E402
from app.drivers.demo import DriverDemo         # noqa: E402
from app.registry import TELECAMERE             # noqa: E402


class ProveDriverDemo(unittest.TestCase):

    def setUp(self):
        self.driver = DriverDemo(TELECAMERE["acepro2"])
        self.driver.collega()

    def tearDown(self):
        self.driver.annulla_autoscatto()
        self.driver.scollega()

    def test_scatto_foto_crea_un_file(self):
        self.driver.imposta_modalita("foto")
        prima = self.driver.stato()
        self.driver.scatta()
        dopo = self.driver.stato()
        self.assertEqual(len(dopo["file"]), len(prima["file"]) + 1)
        self.assertLess(dopo["memoria_libera_gb"], prima["memoria_libera_gb"])
        self.assertEqual(dopo["file"][0]["tipo"], "foto")

    def test_registrazione_video(self):
        self.driver.imposta_modalita("video")
        prima = self.driver.stato()
        self.driver.scatta()
        self.assertTrue(self.driver.stato()["in_registrazione"])
        time.sleep(0.05)
        self.driver.scatta()  # secondo scatto = stop
        dopo = self.driver.stato()
        self.assertFalse(dopo["in_registrazione"])
        self.assertEqual(len(dopo["file"]), len(prima["file"]) + 1)
        self.assertEqual(dopo["file"][0]["tipo"], "video")

    def test_ferma_registrazione_esplicito(self):
        self.driver.imposta_modalita("video")
        self.driver.scatta()
        self.driver.ferma_registrazione()
        self.assertFalse(self.driver.stato()["in_registrazione"])
        with self.assertRaises(ErroreTelecamera):
            self.driver.ferma_registrazione()

    def test_niente_comandi_da_scollegata(self):
        driver = DriverDemo(TELECAMERE["go3s"])
        with self.assertRaises(ErroreTelecamera):
            driver.scatta()

    def test_cambio_modalita_vietato_durante_la_registrazione(self):
        self.driver.imposta_modalita("video")
        self.driver.scatta()
        with self.assertRaises(ErroreTelecamera):
            self.driver.imposta_modalita("foto")
        self.driver.ferma_registrazione()

    def test_impostazioni_valide_e_non(self):
        self.driver.imposta("timer", "3 s")
        self.assertEqual(self.driver.stato()["valori"]["timer"], "3 s")
        with self.assertRaises(ErroreTelecamera):
            self.driver.imposta("timer", "7 s")
        with self.assertRaises(ErroreTelecamera):
            self.driver.imposta("inesistente", "x")

    def test_risoluzione_valida_e_non(self):
        self.driver.imposta_modalita("video")
        self.driver.imposta_risoluzione("4K/60")
        self.assertEqual(self.driver.stato()["risoluzione"], "4K/60")
        with self.assertRaises(ErroreTelecamera):
            self.driver.imposta_risoluzione("12K/240")

    def test_autoscatto_parte_e_si_annulla(self):
        self.driver.imposta_modalita("foto")
        self.driver.imposta("timer", "3 s")
        self.driver.scatta()
        stato = self.driver.stato()
        self.assertIsNotNone(stato["autoscatto_fra"])
        self.assertLessEqual(stato["autoscatto_fra"], 3.0)
        self.driver.annulla_autoscatto()
        self.assertIsNone(self.driver.stato()["autoscatto_fra"])

    def test_elimina_file_libera_memoria(self):
        prima = self.driver.stato()
        nome = prima["file"][0]["nome"]
        self.driver.elimina_file(nome)
        dopo = self.driver.stato()
        self.assertEqual(len(dopo["file"]), len(prima["file"]) - 1)
        self.assertGreater(dopo["memoria_libera_gb"], prima["memoria_libera_gb"])
        with self.assertRaises(ErroreTelecamera):
            self.driver.elimina_file(nome)

    def test_spegni_scollega(self):
        self.driver.spegni()
        self.assertFalse(self.driver.stato()["collegata"])


if __name__ == "__main__":
    unittest.main()
