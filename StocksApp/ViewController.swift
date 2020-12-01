//
//  ViewController.swift
//  StocksApp
//
//  Created by Dmitriy Kara on 01.12.2020.
//

import UIKit
import Foundation

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    @IBOutlet weak var Image: UIImageView!
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyPicker: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private var companies: [String:String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.activityIndicator.hidesWhenStopped = true
        
        self.downloadCompanies()
    }
    
    // MARK: - Private functions
    
    private func showResponseAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel))
    
        alert.addAction(
            UIAlertAction(title: "Exit", style: UIAlertAction.Style.default, handler: {(_: UIAlertAction!) in
                exit(0)
            }))
        
        DispatchQueue.main.async() {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showExitAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertController.Style.alert
        )
    
        alert.addAction(
            UIAlertAction(title: "Exit", style: UIAlertAction.Style.default, handler: {(_: UIAlertAction!) in
                exit(0)
            }))
        
        DispatchQueue.main.async() {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func downloadCompanies() {
        let url = URL(string: "https://sandbox.iexapis.com/stable/stock/market/list/mostactive?listLimit=20&token=Tsk_b569ab301292462c96947f38cb2d814e")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 2
        let session = URLSession(configuration: config)
        
        let dataTask = session.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                print("! Network error")
                self.showExitAlert(title: "Pure internet connection", message: "Please check your internet connection")
                return
            }
            self.parseCompanies(data: data)
        }
        
        dataTask.resume()
    }
    
    private func parseCompanies(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let array = jsonObject as? [[String:Any]]
            else {
                print("! Invalid JSON format")
                self.showExitAlert(title: "Bad server response", message: "Please try again")
                return
            }
            
            for comp in array {
                guard
                    let companyName = comp["companyName"] as? String,
                    let symbol = comp["symbol"] as? String
                else {
                    print("! Invalid JSON format")
                    self.showExitAlert(title: "Bad server response", message: "Please try again")
                    return
                }
                self.companies[companyName] = symbol
            }
            
            DispatchQueue.main.async() {
                self.companyPicker.dataSource = self
                self.companyPicker.delegate = self
                self.requestQuoteUpdate()
            }
        }
        catch {
            print("! JSON parsing error: " + error.localizedDescription)
            self.showExitAlert(title: "Bad server response", message: "Please restart app")
        }
    }
    
    private func requestQuoteUpdate() {
        self.activityIndicator.startAnimating()
        self.Image.image = nil
        self.companyNameLabel.text = "-"
        self.symbolLabel.text = "-"
        self.priceLabel.text = "-"
        self.priceChangeLabel.text = "-"
        self.priceChangeLabel.textColor = UIColor.black
        
        let selectedRow = self.companyPicker.selectedRow(inComponent: 0)
        let selectedSymbol = Array(self.companies.values)[selectedRow]
        self.requestQuote(for: selectedSymbol)
    }
    
    private func requestQuote(for symbol:String) {
        let url = URL(string: "https://sandbox.iexapis.com/stable/stock/\(symbol.lowercased())/batch?types=quote&token=Tsk_b569ab301292462c96947f38cb2d814e")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 2
        let session = URLSession(configuration: config)
        
        let dataTask = session.dataTask(with: url) { data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
            else {
                print("! Network error")
                self.showResponseAlert(title: "Pure internet connection", message: "Please check your internet connection")
                return
            }
            self.parseQuote(data: data)
        }
        
        dataTask.resume()
    }
    
    private func downloadImage(for symbol: String) {
        let url = URL(string: "https://storage.googleapis.com/iex/api/logos/\(symbol).png")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 2
        let session = URLSession(configuration: config)
        
        let dataTask = session.dataTask(with: url) { data, response, error in
            guard
                let data = data,
                error == nil
            else {
                print("! Can't load image")
                self.showResponseAlert(title: "Pure internet connection", message: "Please check your internet connection")
                return
            }
            DispatchQueue.main.async() {
                self.Image.image = UIImage(data: data)
            }
        }
        dataTask.resume()
    }
    
    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let quote = json["quote"] as? [String: Any],
                let companyName = quote["companyName"] as? String,
                let symbol = quote["symbol"] as? String,
                let price = quote["latestPrice"] as? Double,
                let change = quote["change"] as? Double
            else {
                print("! Invalid JSON format")
                self.showResponseAlert(title: "Bad server response", message: "Please try again")
                return
            }
            DispatchQueue.main.async {
                self.displayStockInfo(company: companyName, symbol: symbol, price: price, priceChange: change)
            }
        }
        catch {
            print("! JSON parsing error: " + error.localizedDescription)
            self.showResponseAlert(title: "Bad server response", message: "Please try again")
        }
    }
    
    private func displayStockInfo(company: String, symbol: String, price: Double, priceChange: Double) {
        self.companyNameLabel.text = company
        self.symbolLabel.text = symbol
        self.priceLabel.text = "\(price)"
        self.priceChangeLabel.text = "\(priceChange)"
        if priceChange > 0 {
            self.priceChangeLabel.textColor = UIColor.systemGreen
        }
        if priceChange < 0 {
            self.priceChangeLabel.textColor = UIColor.systemRed
        }
        self.downloadImage(for: symbol)
        self.activityIndicator.stopAnimating()
    }
    
    // MARK: - PickerView

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        requestQuoteUpdate()
    }
}

