//
//  EventEditView.swift
//  Basket
//
//  Created by Thibault Giraudon on 23/12/2023.
//

import SwiftUI
import SDWebImageSwiftUI
import PhotosUI

class PhotoSelectorViewModel: ObservableObject {
    @Published var photo = UIImage()
    @Published var selectedPhotos = [PhotosPickerItem]()
    @Published var isSelected = false
    
    @MainActor
    func convertDataToImage() {
        isSelected = false
        if !selectedPhotos.isEmpty {
            for eachItem in selectedPhotos {
                Task {
                    if let imageData = try? await eachItem.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: imageData) {
                            photo = image
                            isSelected = true
                        }
                    }
                }
            }
        }
        
        selectedPhotos.removeAll()
    }
}

struct EventEditView: View {
    @StateObject var viewModel: EventViewModel
    @Environment(\.dismiss)var dismiss
    
    @StateObject var vm = PhotoSelectorViewModel()
    @State private var isUploaded = false
    @State private var showAlertImage = false
    @State private var showAlert = false
    @State private var showPhotoPicker1 = false
    @State private var showPhotoPicker2 = false
    @State private var uploadSuccess = false
    @State private var saveSuccess = false
    @State private var selectedImage: URL?
    let maxPhotosToSelect = 1
    private var ranks = ["LF1", "LF2", "N1", "N2", "N3", "R1", "R2", "R3", "R4", "D1", "D2", "D3", "D4"]
    private var groups = ["A", "B", "C", "D", "E", "F"]
    @State private var selectedRank = "LF2"
    @State private var selectedDay = 0
    @State private var selectedGroup = "A"
    @State private var score1 = ""
    @State private var score2 = ""
    private var types = ["match", "autre"]
    
    init(viewModel: EventViewModel = EventViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            Form {
            Picker("Type", selection: $viewModel.type) {
                ForEach(types, id: \.self) { type in
                    Text(type)
                }
            }
            .pickerStyle(.inline)
            DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
            DatePicker("Heure", selection: $viewModel.date, displayedComponents: [.hourAndMinute])
            if viewModel.type == "match" {
                Picker("Niveau", selection: $selectedRank) {
                    ForEach(ranks, id: \.self) { rank in
                            Text(rank)
                    }
                }
                Picker("Journée", selection: $selectedDay) {
                    ForEach(1..<23) { index in
                            Text("\(index)")
                    }
                }
                Picker("Groupe", selection: $selectedGroup) {
                    ForEach(groups, id: \.self) { char in
                            Text(char)
                    }
                }
                VStack(alignment: .leading) {
                    TextField("Domicile", text: $viewModel.team1_name)
                    TextField("Score domicile", text: $score1)
                        .keyboardType(.numberPad)
                    if !viewModel.team1_image.isEmpty {
                        WebImage(url: URL(string: viewModel.team1_image))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                    Button{
                        showPhotoPicker1.toggle()
                    } label: {
                        Text("Logo domicile")
                    }
                    .sheet(isPresented: $showPhotoPicker1, content: {
                        NavigationStack {
                            FirebasePhotoPicker(selectedImage: $viewModel.team1_image)
                                .navigationBarItems (
                                    leading:
                                        Button(action: { showPhotoPicker1.toggle() }) {
                                            Text("Cancel")
                                        }
                                )
                        }
                    })
                }
                VStack(alignment: .leading) {
                    TextField("Visiteur", text: $viewModel.team2_name)
                    TextField("Score visiteur", text: $score2)
                        .keyboardType(.numberPad)
                    if !viewModel.team2_image.isEmpty {
                        WebImage(url: URL(string: viewModel.team2_image))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                    Button{
                        showPhotoPicker2.toggle()
                    } label: {
                        Text("Logo visiteur")
                    }
                    .sheet(isPresented: $showPhotoPicker2, content: {
                        NavigationStack {
                            FirebasePhotoPicker(selectedImage: $viewModel.team2_image)
                                .navigationBarItems (
                                    leading:
                                        Button(action: { showPhotoPicker2.toggle() }) {
                                            Text("Cancel")
                                        }
                                )
                        }
                    })
                }
            }
            else {
                TextField("Titre", text: $viewModel.title)
                TextField("Description", text: $viewModel.description)
                VStack {
                    if (vm.isSelected) {
                        Image(uiImage: vm.photo)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                    }
                    PhotosPicker(
                        selection: $vm.selectedPhotos,
                        maxSelectionCount: maxPhotosToSelect,
                        selectionBehavior: .ordered,
                        matching: .images
                    ) {
                        Text("Ajouter photo")
                    }
                }
            }
        }
            Spacer()
            if case .add = viewModel.formType {
                Button {
                    if ((viewModel.type == "match" && !viewModel.team1_image.isEmpty && !viewModel.team2_image.isEmpty) && !viewModel.type.isEmpty){
                        Task {
                            do {
                                viewModel.info = selectedRank + ", Journée " + String(selectedDay + 1)
                                viewModel.info += ", Group " + String(selectedGroup)
                                viewModel.score = score1 + " - " + score2
                                viewModel.title = viewModel.team1_name + " vs " + viewModel.team2_name
                                try await viewModel.save()
                                viewModel.clear()
                                saveSuccess = true
                            } catch {}
                        }
                    }
                    else if ((viewModel.type == "autre" && !viewModel.title.isEmpty && !viewModel.description.isEmpty) && !viewModel.type.isEmpty){
                        Task {
                            do {
                                viewModel.info = viewModel.description
                                await viewModel.uploadImage(vm.photo)
                                try await viewModel.save()
                                viewModel.clear()
                                saveSuccess = true
                            } catch {}
                        }
                    }
                    else {
                        showAlert = true
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .frame(width: 250, height: 50)
                            .foregroundStyle(.green)
                        Text("Ajouter l'evenement")
                            .foregroundStyle(.white)
                    }
                }
                .alert(viewModel.type == "match" ? "Pensez a remplir tous les champs" : "Pensez a televerser l'image et a remplir tous les champs", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                }
                .alert("Evenement ajoute avec succes", isPresented: $saveSuccess) {
                    Button("OK", role: .cancel) { }
                }
            }
        }
        .onChange(of: vm.selectedPhotos) { _, _ in
            vm.convertDataToImage()
        }
        .toolbar {
            if case .edit = viewModel.formType {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sauvegarder") {
                        Task {
                            do {
                                try await viewModel.save()
                                dismiss()
                            } catch {}
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EventEditView()
    }
}
