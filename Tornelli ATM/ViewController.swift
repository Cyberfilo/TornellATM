import UIKit
import CoreML
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // Dizionario per mappare le etichette delle persone ai numeri e agli ID
    let personIDMapping: [String: (id: String, code: String)] = [
        "0 Jeff_bezos": ("0", "1234"),
        "1 Steve_jobs": ("1", "5678"),
        "2 Bill_gates": ("2", "9101"),
        "3 Antonella_sgobba": ("3", "5678"),
        "4 Filippo_menghi": ("4", "1234")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        // Creiamo un pulsante
        let choosePhotoButton = UIButton(type: .system)
        choosePhotoButton.setTitle("Scegli una foto", for: .normal)
        choosePhotoButton.frame = CGRect(x: 100, y: 200, width: 200, height: 50)
        choosePhotoButton.addTarget(self, action: #selector(choosePhoto), for: .touchUpInside)

        // Aggiungiamo il pulsante alla vista
        self.view.addSubview(choosePhotoButton)
    }

    // Funzione per gestire l'immagine scelta
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        // Otteniamo l'immagine scelta
        guard let image = info[.originalImage] as? UIImage else { return }
        recognizePerson(in: image)
    }

    // Funzione per usare il modello ML per riconoscere la persona
    func recognizePerson(in image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }

        // Carica il modello Core ML usando la configurazione aggiornata
        let config = MLModelConfiguration()
        guard let model = try? MyImageClassifier(configuration: config).model else {
            fatalError("Non è stato possibile caricare il modello ML")
        }

        // Creiamo un oggetto VNCoreMLModel dal modello
        guard let visionModel = try? VNCoreMLModel(for: model) else {
            fatalError("Non è stato possibile creare VNCoreMLModel dal modello Core ML")
        }

        // Crea una richiesta per il modello
        let request = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                return
            }

            // Prendiamo il risultato migliore
            if let bestResult = results.first {
                let personLabel = bestResult.identifier
                print("Persona riconosciuta: \(personLabel)")

                // Usa il dizionario per trovare l'ID e il numero associato alla persona
                if let personData = self?.personIDMapping[personLabel] {
                    let personID = personData.id
                    let personCode = personData.code
                    print("Numero associato: \(personCode), ID persona: \(personID)")

                    // Invia l'ID e il codice al server Flask
                    self?.sendPersonDataToServer(personID: personID, personCode: personCode)
                } else {
                    print("Persona non trovata nella mappatura")
                }
            }
        }

        // Esegui la richiesta sulla foto
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Errore nell'esecuzione della richiesta: \(error)")
        }
    }

    // Funzione per inviare l'ID e il codice al server Flask
    func sendPersonDataToServer(personID: String, personCode: String) {
        guard let url = URL(string: "https://cd06-2001-b07-ae6-1b54-91b9-14cc-9c9a-e72c.ngrok-free.app/update_color") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["person_id": personID, "person_code": personCode]

        // Codifica il corpo della richiesta in JSON
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else { return }
        request.httpBody = httpBody

        // Esegui la richiesta
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Errore nell'invio della richiesta: \(error)")
                return
            }
            print("Richiesta inviata con successo")
        }
        task.resume()
    }

    // Funzione per permettere all'utente di scegliere una foto dalla galleria
    @objc func choosePhoto() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
}
