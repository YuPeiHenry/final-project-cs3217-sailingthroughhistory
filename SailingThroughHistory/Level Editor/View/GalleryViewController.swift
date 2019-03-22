//
//  GallaryViewController.swift
//  SailingThroughHistory
//
//  Created by ysq on 3/22/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import UIKit

class GalleryViewController: UIViewController {
    private var storage = Storage()
    private var levelNames: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        levelNames = storage.getAllRecords()
        // Do any additional setup after loading the view.
    }
    @IBAction func cancelPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func confirmPressed(_ sender: Any) {
        //TODO: move load here
    }
}

extension GallaryViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return levelNames.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "record", for: indexPath)
            as? GalleryCollectionViewCell else {
                fatalError("Cell cannot be casted into GallaryCollectionViewCell")
        }
        let levelName = levelNames[indexPath.item]
        cell.label.text = levelName
        cell.previewImage.image = storage.readPreviewImage(levelName)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let levelName = levelNames[indexPath.item]
        guard let gameParameter: GameParameter = storage.readLevelData(levelName) else {
            // TODO: raise alert and delete the data
            //fatalError("level data broken")
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "levelEditorScreen")

        guard let castedController = controller as? LevelEditorViewController else {
            fatalError("LevelEditorViewController not found.")
        }
        self.present(castedController, animated: true, completion: nil)
    }
}