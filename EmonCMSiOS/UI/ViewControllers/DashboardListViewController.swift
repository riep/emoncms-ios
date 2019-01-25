//
//  DashboardListViewController.swift
//  EmonCMSiOS
//
//  Created by Matt Galloway on 24/01/2019.
//  Copyright © 2019 Matt Galloway. All rights reserved.
//

import UIKit
import SafariServices

import RxSwift
import RxCocoa
import RxDataSources
import RxAppState

final class DashboardListViewController: UITableViewController {

  var viewModel: DashboardListViewModel!

  private var emptyLabel: UILabel?
  @IBOutlet private var refreshButton: UIBarButtonItem!
  @IBOutlet private var lastUpdatedLabel: UILabel!

  private let disposeBag = DisposeBag()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Dashboards"
    self.view.accessibilityIdentifier = AccessibilityIdentifiers.Lists.Dashboard

    self.setupDataSource()
    self.setupBindings()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Annoyingly this has to be in DIDappear and not WILLappear, otherwise it causes a weird
    // navigation bar bug when going back to the feed list view from a feed detail view.
    self.viewModel.active.accept(true)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.viewModel.active.accept(false)
  }

  private func setupDataSource() {
    let dataSource = RxTableViewSectionedReloadDataSource<DashboardListViewModel.Section>(
      configureCell: { (ds, tableView, indexPath, item) in
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = item.name
        cell.detailTextLabel?.text = item.desc
        return cell
    },
      titleForHeaderInSection: { _,_  in "" },
      canEditRowAtIndexPath: { _,_  in true },
      canMoveRowAtIndexPath: { _,_  in false })

    self.tableView.delegate = nil
    self.tableView.dataSource = nil

    self.viewModel.dashboards
      .map { [DashboardListViewModel.Section(model: "", items: $0)] }
      .drive(self.tableView.rx.items(dataSource: dataSource))
      .disposed(by: self.disposeBag)
  }

  private func setupBindings() {
    let refreshControl = self.refreshControl!
    let appBecameActive = UIApplication.shared.rx.applicationDidBecomeActive.becomeVoid()
    Observable.of(self.refreshButton.rx.tap.asObservable(),
                  refreshControl.rx.controlEvent(.valueChanged).asObservable(),
                  appBecameActive)
      .merge()
      .bind(to: self.viewModel.refresh)
      .disposed(by: self.disposeBag)

    let dateFormatter = DateFormatter()
    self.viewModel.updateTime
      .map { time in
        var string = "Last updated: "
        if let time = time {
          if time.timeIntervalSinceNow < -86400 {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
          } else {
            dateFormatter.dateStyle = .none
            dateFormatter.timeStyle = .medium
          }
          string += dateFormatter.string(from: time)
        } else {
          string += "Never"
        }
        return string
      }
      .drive(self.lastUpdatedLabel.rx.text)
      .disposed(by: self.disposeBag)

    self.viewModel.isRefreshing
      .drive(refreshControl.rx.isRefreshing)
      .disposed(by: self.disposeBag)

    self.tableView.rx
      .modelSelected(DashboardListViewModel.ListItem.self)
      .subscribe(onNext: { [weak self] in
        guard let self = self else { return }
        self.openDashboard(withId: $0.dashboardId)
      })
      .disposed(by: self.disposeBag)

    self.viewModel.dashboards
      .map {
        $0.count == 0
      }
      .drive(onNext: { [weak self] empty in
        guard let self = self else { return }

        self.tableView.tableHeaderView?.isHidden = empty

        if empty {
          let emptyLabel = UILabel(frame: CGRect.zero)
          emptyLabel.translatesAutoresizingMaskIntoConstraints = false
          emptyLabel.text = "Cannot fetch dashboards.\n\nYou may need to upgrade Emoncms to be able to fetch dashboards. Please check that your Emoncms is up-to-date and then try again."
          emptyLabel.numberOfLines = 0
          emptyLabel.textColor = .lightGray
          emptyLabel.textAlignment = .center
          self.emptyLabel = emptyLabel

          self.view.addSubview(emptyLabel)
          self.view.addConstraint(NSLayoutConstraint(
            item: emptyLabel,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: self.view,
            attribute: .centerX,
            multiplier: 1,
            constant: 0))
          self.view.addConstraint(NSLayoutConstraint(
            item: emptyLabel,
            attribute: .leading,
            relatedBy: .greaterThanOrEqual,
            toItem: self.view,
            attribute: .leading,
            multiplier: 1,
            constant: 8))
          self.view.addConstraint(NSLayoutConstraint(
            item: emptyLabel,
            attribute: .trailing,
            relatedBy: .lessThanOrEqual,
            toItem: self.view,
            attribute: .trailing,
            multiplier: 1,
            constant: 8))
          self.view.addConstraint(NSLayoutConstraint(
            item: emptyLabel,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: self.view,
            attribute: .top,
            multiplier: 1,
            constant: 44.0 * 1.5))
        } else {
          if let emptyLabel = self.emptyLabel {
            emptyLabel.removeFromSuperview()
          }
        }
      })
      .disposed(by: self.disposeBag)
  }

  private func openDashboard(withId dashboardId: String) {
    guard let url = self.viewModel.urlForDashboard(withId: dashboardId) else {
      AppLog.error("Failed to create URL for dashboard with id: \(dashboardId)")
      return
    }

    let viewController = SFSafariViewController(url: url)
    viewController.dismissButtonStyle = .close
    self.present(viewController, animated: true, completion: nil)
  }

}
